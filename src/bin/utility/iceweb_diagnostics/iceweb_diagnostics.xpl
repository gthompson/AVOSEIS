eval 'exec perl -S $0 "$@"'
##############################################################################
# Author: Glenn Thompson (GT) 1998-1999 and 2007-2008, UNIVERSITY OF ALASKA FAIRBANKS
#
# Modifications:
#
# Purpose:
#
# Just do some simple checks to see if IceWeb is running	
##############################################################################

use Datascope;
require "getopts.pl" ;
 
use strict;
use warnings;
our $PROG_NAME;
($PROG_NAME = $0) =~ s(.*/)();	# PROG_NAME becomes $0 minus any path

# End of  GT Antelope Perl header
##############################################################################
use File::Basename;

# Define variables
our %paths;
our($pathspf, $parameterspf, $subnetspf);
our ($convert, $ALCHEMY); 
our %imageFormat;
our $makeHTML;
our ($subnetsref, @subnets);
my ($subnet);

# read paths
$paths{PFS} 		= $ARGV[0]; 
$pathspf 		= $paths{PFS}."/paths.pf"; 
$parameterspf		= $paths{PFS}."/iceweb_parameters.pf";
$subnetspf		= $paths{PFS}."/iceweb_subnets.pf";
$paths{ICEWEB_PLOTS_WEB}= "www_iceweb2_op";

our $rundir = dirname($paths{PFS});


# start output page
my $outfile = $paths{ICEWEB_PLOTS_WEB}."/diagnostics.html";
open(FOUT, ">$outfile");
print FOUT "<html><head><title>IceWeb Diagnostics</title></head>";
my $date = `date`;
printf FOUT "<body><p>$date</p><table border=1>";

# get the list of subnets
$subnetsref = pfget($subnetspf, "subnets");
@subnets = @$subnetsref;

&display_scalar("<h3>Number of subnets</h3>", $#subnets + 1, "@subnets");
#&display_array("Subnets", @subnets);

# Check age of last touch file modification
my ($field2, $field3);
my $touchfile = "$rundir/logs/iceweb2";
my $age = 0.0;
if (-e $touchfile) {
	$age = int((-M $touchfile) * 24);
	$field2 = $age. " hours ago";
	$field3 = "";
}
else
{
	$field2 = "unknown";
	$field3 = "$touchfile does not exist";
}
&display_scalar("rtrun_iceweb2 last ran", $field2, $field3);

if ($age > 1) {
	&run("echo \"rtrun_iceweb2 last ran $age hours ago\" | rtmail -s \"IceWeb2 $subnet down?\" gthompson\@alaska.edu", 1);
} 


# Dr Image files
&display_scalar("", "", "");
&display_scalar("<h3>DR IMAGE FILES</h3>", "", "");
foreach my $subnet (@subnets) {
	my $globstring = $paths{ICEWEB_PLOTS_WEB}."/plots/tmdrs/".$subnet."*.png";
	&drfiles($globstring, $subnet);

}

# Sp Final image files
#&display_scalar("", "", "");
#&display_scalar("<h3>SPECTROGRAM IMAGE FILES</h3>", "", "");
#foreach my $subnet (@subnets) {
#print FOUT "<tr><td>$subnet</td></tr>\n";
#	my $globstring = $paths{ICEWEB_PLOTS_WEB}."/plots/sp/".$subnet."/2*/*/*/2*.png";
#	&spfiles($globstring, $subnet);
#}


# How long things are taking
&display_scalar("", "", "");
&display_scalar("<h3>HOW LONG</h3>", "", "");
my $totaltime = `grep "total" logs/iceweb2 | tail -1`;
&display_scalar("iceweb2", $totaltime, "");



# Close html page
print FOUT "</table></body></html>";
close FOUT;

1;

sub display_scalar {
	my @field = @_;
	my @width = qw(100 200 300);
	print FOUT "<tr>";
	foreach my $f (@field) {
		my $w = shift @width;
		if ($f eq "") {
			$f = "-";
		}
		print FOUT "<td width=$w>$f</td>";
	}
	print FOUT "</tr>\n"; 
}


sub spfiles {
	my ($globstring, $subnet) = @_; 
	#print "globstring = $globstring\n";
	my @allfiles = `ls -rt $globstring`;
	my ($field2, $field3);
	$field2 = ($#allfiles + 1) . " files";
	$field3 = "";
	if ($#allfiles > -1) {
		my $firstfile = basename $allfiles[0];
		my $lastfile  = basename $allfiles[$#allfiles];
		chomp($firstfile);
		chomp($lastfile);
		$field3    = "$firstfile - $lastfile";
	}
	&display_scalar($subnet, $field2, $field3);
}

	
sub drfiles {
	my ($globstring, $subnet) = @_;
	my @allfiles = `ls -rt $globstring`;
	if ($#allfiles > -1) {
		foreach my $file (@allfiles) {
			chomp($file);
			my $agehours = int((-M $file) * 24); 
			my $field1 = $subnet."/".basename $file;
			my $field2 = "Age in hours is $agehours";
			&display_scalar($field1, $field2, "");
			if ($agehours > 24) {
				system("rm $file");
			}
		}
	}
	else
	{
		&display_scalar($subnet, "0 files", "");

	}

}


#######################################################

sub run {               # run system cmds safely
     # mode 0 = testing, 1 = running & echo command, 2 = run, but don't echo command	
     my ( $cmd, $mode ) = @_ ;
     my $modeStr;
     if ($mode == 0) {
	$modeStr = "Testing:";
     }
     else
     {
	$modeStr = "Running:";
     }
     print "$modeStr\n$cmd\n" if ($mode==1);
     my $value = "";
     $value = `$cmd` if $mode;
     chomp($value);
     $value =~ s/\s*//g;

     if ($?) {
         print STDERR "$cmd error $? \n" ;
         return "Error";
     }

     return $value;
}		
	
