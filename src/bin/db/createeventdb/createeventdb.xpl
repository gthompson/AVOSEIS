
require "getopts.pl" ;
our ($opt_a, $opt_d);
if ( ! &Getopts('ad') || $#ARGV == -1 ) {
    my $pgm = $0 ;
    $pgm =~ s".*/"" ;
    die("Usage:\n $pgm [-ad] sdate edate reflonWEST reflatNORTH volcano_code\n\ne.g.\n$pgm '2008/6/1' '2008/9/1' 168.16 53.42 OK\n   -a - rerun associations\n   -d - rerun detections\n" ) ;
}

use Datascope ;

# This is a fully functional, though somewhat simplified, example of the pseudo 
# real time earthquake location.
#
# The real meat lives in the parameter file settings in the directory pf.
# These parameter files have been customized for the Okmok dataset 
# but can certainly be improved. 
#
# Most of the details herein can be understood by browsing the man pages 
# and the parameter files for the following routines: dbdetect, ttgrid, 
# dbgrassoc and dbml. The dbgenloc man page is also relevant.

# Process input arguments
($sdate, $edate, $reflon, $reflat, $VC) = @ARGV;
$reflon = -$reflon;


# Create name for merged event database
$sepoch = str2epoch($sdate);
$eepoch = str2epoch($edate);
$sYYYYMMDD = epoch2str($sepoch, "%Y%m%d");
$eYYYYMMDD = epoch2str($eepoch, "%Y%m%d");


if (-e "dbseg") {
	$dbdir = "dbseg";
}
else
{
	$dbdir = "db";
}
$eventdbmaster = "$dbdir/quakes_$VC_$sYYYYMMDD_$eYYYYMMDD";
print "The merged event database you create will be called $eventdbmaster\n";

# Create directory for old tables
$oldtablesdir = "$dbdir/oldtables";
if (!(-e $oldtablesdir)) {
	print "Creating $oldtablesdir\n";
	system("mkdir -p $oldtablesdir");
}
$timestamp = epoch2str(now(),"%H%M");
print "timestamp = $timestamp\n";


# Create velocity grid to nearby stations
unless (-e "dbmaster/grid_$VC") {
	if (-e "dbmaster/master_stations.site") {
		print "Creating velocity grid, step 1/2\n";
		# in dbe it is useful to subset on: deg2km(distance(lat,lon,60.0319, -153.0918))<50 && offdate==NULL
		# get volcano coords from pf/avo_volcs.pf
		system("dbsubset dbmaster/master_stations.site \"deg2km(distance(lat,lon,$reflat, $reflon))<50\" | dbunjoin -o tmp -");
	}
	else
	{
		die("No file dbmaster/master_stations.site\n");
	}

	if (-e "pf/ttgrid_$VC.pf") {
		print "Creating velocity grid, step 2/2\n";
		system("ttgrid -pf ttgrid_$VC tmp > dbmaster/grid_$VC");
	}
	else
	{
		die("No file pf/ttgrid_$VC.pf\n");
	}
	
}

# Show travel-time grid 
system("ttgrid_show -N dbmaster/grid_$VC");                    # list stations
system("displayttgrid -shownames dbmaster/grid_$VC lo_$VC");    # show map of a specific grid

# Loop over days
for ($time = $sepoch; $time < $eepoch; $time+=86400) {
	$YYYYMMDD = epoch2str($time, "%Y_%m_%d");

	$eventdb = "$dbdir/Quakes_$YYYYMMDD";
	if ($time == $sepoch) {
		$alleventdbs = $eventdb; # This will help to form our descriptor for eventdbmaster
	}
	else
	{
		$alleventdbs = $alleventdbs.":$eventdb";
	}

	if ($opt_d) {
		if (-e "$eventdb.detection") {
			system("cp $eventdb $oldtablesdir");
			system("mv $eventdb.detection $eventdb.detection.$timestamp");
			system("mv $eventdb.detection.$timestamp $oldtablesdir");
		}
	}

	if ($opt_a) {
		if (-e "$eventdb.*") {
			@tables = qw(assoc arrival emodel event lastid netmag origerr origin predarr stamag);
			foreach $table (@tables) {
				system("cp $eventdb $oldtablesdir");
				system("mv $eventdb.$table $eventdb.$table.$timestamp");
				system("mv $eventdb.$table.$timestamp $oldtablesdir");
			}
		}
	}

	# Create descriptor file
	print "Creating descriptor for $YYYYMMDD\n";
	if (!(-e $eventdb)) { 
		open(FDES,">$eventdb");
		print FDES<<EOF
#
schema css3.0
dblocks none
dbidserver
dbpath /iwrun/op/db/archive/{archive_$YYYYMMDD}:../dbmaster/{master_stations}
EOF
;
		close(FDES);
	}

	if (!(-e "$eventdb.detection") || $opt_d) {
		# Run detections if a detection table for this day does not already exist
		if (-e "pf/dbdetect_$VC.pf") {
			print "Creating detection table for $eventdb\n";
			system("dbdetect -tstart $time -twin 86400 -pf dbdetect_$VC $eventdb $eventdb >& logs/dbdetect_$VC");
		}
		else
		{
			die("pf/dbdetect_$VC.pf does not exist: Cannot create detection table for $eventdb\n");
		}
	}

	if (!(-e "$eventdb.assoc") || $opt_a) {
		# ASSOCIATE DETECTIONS INTO HYPOCENTERS 
		if (-e "pf/dbgrassoc_$VC.pf") {
			print "Associating detections to create assoc and event tabkes for $eventdb\n";
			system("dbgrassoc -pf dbgrassoc_$VC  $eventdb  $eventdb  dbmaster/grid_$VC >& logs/dbgrassoc_$VC");
		}
		else
		{
			die("pf/dbgrassoc_$VC.pf does not exist: Cannot create assoc & event tables for $eventdb\n");			
		}

		# CALCULATE MAGNITUDES WHERE POSSIBLE
		if (-e "pf/dbml_$VC.pf") {
			print "Calculating magnitudes for $eventdb\n";
			system("dbml -make_magtables -p dbml_$VC $eventdb >& logs/dbml_$VC");
			system("dbset $eventdb ml \'ml == NULL\' -1.000");   # Set NULL magnitudes to default value
		}
		else
		{
			die("pf/dbml_$VC.pf does not exist: Cannot compute magnitudes for $eventdb\n");
		}
	}

	# MERGE DATABASE
	print "Merging $eventdb with $eventdbmaster\n";
	if (-e $eventdbmaster) {
		system("dbmerge -x detect,wfdisc $eventdb $eventdbmaster");
	}
	else
	{
		system("$AVOSEIS/bin/renamefiles $eventdb $eventdbmaster");
	}
}




