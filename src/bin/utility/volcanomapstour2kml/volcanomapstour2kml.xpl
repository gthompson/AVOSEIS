eval 'exec perl -S $0 "$@"'
use Datascope;
require "getopts.pl" ;
use strict;
#use warnings;
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();	# PROG_NAME becomes $0 minus any path

######################################################################
# Load seismicity map regions (regions/volcano_maps) 
# Write out KML
####################################################################

# Usage - command line options and arguments
if (  $#ARGV > -1 ) {
        print STDERR <<"EOU" ;

        Usage: $PROG_NAME 

        $PROG_NAME creates a KML file containing:
	- boxes of station maps as used on internal web page

EOU
        exit 1 ;
}

#use List::Util qw[min max];
use Avoseis::SwarmAlarm qw(runCommand prettyprint);

my $mapregiondb = "regions/volcano_maps";
my $volcanodb = "places/volcanoes";
############## Open the KML file and print header and styles
use Env;
my $view_lat = 58;
my $view_lon = -153;
my $view_range = 2000000;

my $kmlfile = $ENV{'INTERNALWEBPRODUCTS'}."/data/kml/$PROG_NAME.kml";
my $kmlfilecopy = $ENV{'PUBLICWEBPRODUCTS'}."/kml/$PROG_NAME.kml";
print "Writing to $kmlfile\n";
open(FKML,">$kmlfile") or die("Cannot open $kmlfile\n");
print FKML &kml_header($PROG_NAME);

#############

# Load the list of 52 historically active volcanoes
my @volcanoes = [];
&getvolcanoplaces($volcanodb, \@volcanoes);


# Print KML folder corresponding to short-term seismicity maps on internal page
if ($#volcanoes > 0) {
   print FKML "<Folder>\n<name>Maps</name>\n";
   print FKML "<gx:Tour>  <name>Play me!</name>  <gx:Playlist>\n";
   my $volcano;
   foreach $volcano (@volcanoes) {
	# volcano is a hash reference
	
	# get map range - could add this as $$volcano{'minlon'} etc.
	my @vertices = [];
	&get_region($mapregiondb, $$volcano{'name'}, \@vertices);

	# add latlon boxes corresponding to map range
	print FKML &kml_tour($$volcano{'name'}, @vertices) if ($#vertices > 2);

   }
   print FKML " </gx:Playlist>  </gx:Tour>\n";

#   foreach $volcano (@volcanoes) {
#	# volcano is a hash reference
#	print "Map for ",$$volcano{'name'}, "\n";
#	
#	# get map range - could add this as $$volcano{'minlon'} etc.
#	my @vertices = [];
#	&get_region($mapregiondb, $$volcano{'name'}, \@vertices);
#
#	# add latlon boxes corresponding to map range
#	print FKML &kml_linestring($$volcano{'name'}." map", "#linestyle_map", @vertices) if ($#vertices > 2);
#
#   }
   print FKML "</Folder>\n";
}


# Close the KML document
print FKML "</Document>\n";
print FKML &kml_footer();
close(FKML);

# Produce a copy of the file on the public server
&runCommand("cp $kmlfile $kmlfilecopy", 1);

########################################################################
#################################################################
### KML_HEADER
###
### $str = &kml_header($kmldoc_name);
#################################################################

sub kml_header {
        my $DOCUMENTNAME = $_[0];
        my $str =<<"EOF";
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
 xmlns:gx="http://www.google.com/kml/ext/2.2">
<Document>
        <name>$DOCUMENTNAME</name>

        <LookAt><longitude>$view_lon</longitude><latitude>$view_lat</latitude><altitude>0</altitude><range>$view_range</range><tilt>0</tilt><heading>0</heading></LookAt>

        <Style id="linestyle_map">
                <LineStyle>
                        <color>7f0000ff</color>
                        <width>4</width>
                </LineStyle>
        </Style>
EOF

        return $str;
}
#################################
### KML FOOTER
###
### $str = &kml_footer();
#################################
sub kml_footer {
        return "</kml>\n";
}
####################################################
### KML LINESTRING
###
### $str = &kml_linestring($label, $linestyle, @vertices)
######################################################
sub kml_linestring {
        my ($label, $linestyle, @vertices) = @_;
        my $str = "<Placemark>\n";
        $str .= "\t<name>$label</name>\n";

        $str .= "\t<styleUrl>$linestyle</styleUrl>\n";
        $str .= "\t<LineString>\n";
        $str .= "\t\t<extrude>0</extrude>\n";
        $str .= "\t\t<tessellate>1</tessellate>\n";
        $str .= "\t\t<altitudeMode>clampToGround</altitudeMode>\n";
        $str .= "\t\t<coordinates>\n";
        foreach my $vertex (@vertices) {
                $str .= "\t\t\t$$vertex{'lon'},$$vertex{'lat'}\n";
        }
        # Add the first vertex again to complete closed loop
        my $vertex = $vertices[0];
        $str .= "\t\t\t$$vertex{'lon'},$$vertex{'lat'}\n";
        $str .= "\t\t</coordinates>\n";
        $str .= "\t</LineString>\n";
        $str .= "</Placemark>\n";
        return $str;
}


sub kml_tour {
	my ($volcano, @vertices) = @_;
	my $str="";
	my $minlon = 999; 
	my $minlat = 999;
	my $maxlon = -999;
	my $maxlat = -999;
	my $sumlon = 0; my $sumlat = 0;
	foreach my $vertex (@vertices) {
		$sumlon += $$vertex{'lon'};
		$sumlat += $$vertex{'lat'};

		$minlon = $$vertex{'lon'} if ($$vertex{'lon'} < $minlon);
		$minlat = $$vertex{'lat'} if ($$vertex{'lat'} < $minlat);
		$maxlon = $$vertex{'lon'} if ($$vertex{'lon'} > $maxlon);
		$maxlat = $$vertex{'lat'} if ($$vertex{'lat'} > $maxlat);

        }
	my $lon = $sumlon / ($#vertices + 1);
	my $lat = $sumlat / ($#vertices + 1);

	my $lonrange = $maxlon - $minlon;
	my $latrange = $maxlat - $minlat;
	my $avrange = ($latrange + $lonrange)/2;
	my $alt = 50000 / 0.5 * $avrange;
	$str=<<"EOD";


      <gx:FlyTo>
        <gx:duration>10.0</gx:duration>
        <!-- bounce is the default flyToMode -->
        <Camera>
          <longitude>$lon</longitude>
          <latitude>$lat</latitude>
          <altitude>$alt</altitude>
          <heading>0</heading>
          <tilt>0</tilt>
        </Camera>
      </gx:FlyTo>
EOD
	return $str;
}






###############################################################
### GET_REGION
###
### $success = &get_region($regiondb, $regname, \%vertices);
###############################################################
sub get_region {
        my ($regiondb, $regname, $verticesref) = @_;
        my @db = dbopen_table("$regiondb.regions", "r") or die("Cannot open $regiondb.regions\n");
        @db = dbsubset(@db, "regname == \"$regname\"");
        my $found = 0;
        my $nvertices = dbquery(@db, "dbRECORD_COUNT");
        my @vertexlist = [];
        if ($nvertices>2) {
                for (my $k = 0; $k < 4; $k++) {
                        $db[3] = $k;
                        my ($lat, $lon) = dbgetv(@db, 'lat', 'lon');
                        my $vertexref = {lat => $lat, lon => $lon};
                        $vertexlist[$k] = $vertexref;
                }
                $found = 1;
        }
        dbclose(@db);
        @$verticesref = @vertexlist;
        return 1;
}

##############################################################
### GETVOLCANOPLACES
###
### $success = &getvolcanoplaces($placesdb, \%volcanoes);
#############################################################
sub getvolcanoplaces {
        my ($volcanodb, $volcanoesref) = @_;
        my @volcanolist = [];
        my @db = dbopen_table("$volcanodb.places", "r");
        @db = dbsort(@db, '-r', 'lon');
        my $nvolcanoes = dbquery(@db, "dbRECORD_COUNT");
        for (my $i=0; $i<$nvolcanoes; $i++) {
                $db[3] = $i;
                # a kludge, we know 4 volcanoes are left of international date line
                my $index = $i - 4;
                $index += $nvolcanoes if ($index < 0);
                my ($name, $lat, $lon) = dbgetv(@db, "place", "lat", "lon");
                my $elev = 0;
                my $volcanoref = {name => $name, lat => $lat, lon => $lon, elev => $elev};
                $volcanolist[$index] = $volcanoref;
                #print "get_volcanoes: ",$$volcanoref{'name'}, $$volcanoref{'lat'}, $$volcanoref{'lon'}, ": \n";
        }
        @$volcanoesref = @volcanolist;
        dbclose(@db);
        return 1;
}

