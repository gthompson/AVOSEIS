# Author: Glenn Thompson (GT) 2011
#         ALASKA VOLCANO OBSERVATORY
#
# History:
#       2011-10-01: Original version of this script read a CSV file 
#       2011-11-01: Ported to use a Datascope PF file 
#
# To do:
#
##############################################################################

use Datascope;

# Get the program name
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();  # PROG_NAME becomes $0 minus any path

# Usage - command line options and arguments
if ( $#ARGV < 1  ) {
    print STDERR <<"EOU" ;

    Usage: $PROG_NAME eventdb xmldirectory

    For more information:
        > man $PROG_NAME
EOU
    exit 1 ;
}

# End of  GT Antelope Perl header
#################################################################
use Avoseis::SwarmAlarm qw(getPf);
($DBNAME, $XMLDIR) = @ARGV[0..1];
$WEEKAGO = (time() + 8 * 60 * 60) - 7 * 24 * 60 * 60;
$YEARAGO = (time() + 8 * 60 * 60) - 365 * 24 * 60 * 60;
$DBMASTER = "/avort/oprun/dbmaster/master_stations";
$pfobjectref = &getPf($PROG_NAME, 0, 0);
$volcanoviewsref = $pfobjectref->{'volcanoviews'};
system("mkdir -p $XMLDIR");
open(FOUT,">$XMLDIR/volcanoviews.xml") or die $!; 
print FOUT "<volcanoes>\n";
foreach $volcanoview (@$volcanoviewsref) {
	print "$volcanoview\n";
		@fields = split(/ /, $volcanoview);
		$volcano = $fields[0];
		$lat = $fields[1];
		$lon = $fields[2];
		$zoom = $fields[3];
		$dist = (2.0 ** (12 - $zoom)) * 5.0;
		print "volcano = $volcano, lat = $lat, lon = $lon, zoom = $zoom, distance = $dist\n";
		system("db2googlemaps -x 2 -b -f -e \"time>$WEEKAGO && deg2km(distance($lat, $lon, lat, lon))<$dist\" $DBNAME  > $XMLDIR/origins_$volcano"."_lastweek.xml");
		system("db2googlemaps -x 2 -b -f -e \"time>$YEARAGO && deg2km(distance($lat, $lon, lat, lon))<$dist\" $DBNAME  > $XMLDIR/origins_$volcano.xml");
		system("db2googlemaps  -x 2 -s -f -e \"deg2km(distance($lat, $lon, lat, lon))<$dist\" $DBMASTER  > $XMLDIR/stations_$volcano.xml");
		print FOUT "<volcano name=\"$volcano\" lat=\"$lat\" lon=\"$lon\" zoomlevel=\"$zoom\" />\n";
}
print FOUT "</volcanoes>\n";
close(FIN);
close(FOUT);