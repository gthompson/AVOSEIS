# make_recent_event_list.pl
# Extract recently-located AVO events and prepare them for display 
# Michael West
# Updated 2/2009
use Datascope ;
use File::Copy;
# Modified by GT 2011/6/13 to use environment variables 
use Env;
$internal = $ENV{'INTERNALWEBPRODUCTS'};
$public = $ENV{'PUBLICWEBPRODUCTS'};


sub descriptor {
	open(OUT,">$dbname");
	print OUT "\#\n";
	print OUT "schema css3.0\n";
	print OUT "dblocks\n";
	print OUT "dbidserver\n";
	print OUT "dbpath\n";
	close(OUT);
}


# SET DB NAME
$dbname 	= "$internal/AVOEQ/db_AVO_recentEQ";
$dbstatin	= "/Seis/Kiska4/master_stations_av/AV/master_stations_AV";
$kmlname 	= "$public/kml/AVO_recentEQ.kml";
$xmlname 	= "$public/kml/AVO_recentEQ.xml";
$xmlsitename 	= "$public/kml/AVO_recentEQ_sites.xml";
$txtname 	= "$internal/AVOEQ/AVO_recentEQ_origins.txt";
$arrname 	= "$internal/AVOEQ/AVO_recentEQ_arrivals.txt";
$timename 	= "$internal/AVOEQ/update_time.txt";
$resphtml 	= "$internal/AVOEQ/responses.html";


# REMOVE OLD DB
@files = glob("$dbname*");
foreach $file (@files) {
	unlink($file);
}


# MAKE TIME FILE
$Tnow = strlocaltime(now());
$command = "echo $Tnow > $timename";
print "\n\n";
print "--------------------------------------------------------------\n";
print "---- SCRIPT RUN TIME: $Tnow\n\n";
print "\n$command\n";
system($command);


# GET LAST 31 DAYS OF LOCATED EVENTS
$epoch1 = now()-2678400;
$D1 = epoch2str($epoch1,'%D');
$epoch2 = now()+86400;	
$D2 = epoch2str($epoch2,'%D');


# MAKE DB
$command = "extractavodb -af $D1 $D2 $dbname";
print "\n$command\n";
system($command);
&descriptor;


# MAKE TEXT ORIGIN FILE
$command = "db2originlist $dbname > $txtname";
print "\n$command\n";
system($command);


# MAKE STATION LIST
$command = "get_avo_stations_db $dbname";
print "$command\n";
system($command);
#copy("$dbstatin.affiliation","$dbname.affiliation");
#copy("$dbstatin.calibration","$dbname.calibration");
#copy("$dbstatin.instrument","$dbname.instrument");
#copy("$dbstatin.network","$dbname.network");
#copy("$dbstatin.schanloc","$dbname.schanloc");
#copy("$dbstatin.sensor","$dbname.sensor");
#copy("$dbstatin.site","$dbname.site");
#copy("$dbstatin.sitechan","$dbname.sitechan");
#copy("$dbstatin.snetsta","$dbname.snetsta");


# MAKE KML FILE
$command = "db2kml -soP $dbname > $kmlname";
print "\n$command\n";
system($command);

# MAKE XML ORIGIN FILE
$command = "db2avoxml -o $dbname > $xmlname";
print "\n$command\n";
system($command);

# MAKE XML SITE FILE
$command = "db2avoxml -s $dbname > $xmlsitename";
print "\n$command\n";
system($command);


# MAKE HTML RESPONSE FILE
$command = "db2responsehtml $dbname > $resphtml";
print "\n$command\n";
system($command);


# MAKE TEXT ARRIVAL FILE
$command = "db2arrivallist $dbname > $arrname";
print "\n$command\n";
system($command);


