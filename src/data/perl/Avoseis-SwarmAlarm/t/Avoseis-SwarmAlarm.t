# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Avoseis-SwarmAlarm.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';
#use Test::More;
use Test::More tests => 28;
BEGIN { use_ok('Avoseis::SwarmAlarm') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
use strict;
use Datascope;
our $AVOSEIS = $ENV{'AVOSEIS'};
#use lib "/home/glenn/sandbox/src/data/perl/Avoseis-SwarmAlarm/blib/lib";
ok(1, "test2\n");

# Test getPf
print STDERR "\nTesting getPf\n";
my $opt_v = 1;
my $PROG_NAME = "dbdetectswarm";
my $opt_p = "../../../bin/db/dbdetectswarm/dbdetectswarm.pf";
ok((-e $opt_p), "parameterfile found\n");
my $pfobjectref = &getPf($PROG_NAME, $opt_p, $opt_v);
my ($alarmclass, $alarmname, $msgdir, $msgpfdir, $volc_name, $volc_code, $twin, $auth_subset, $reminders_on, $escalations_on, $cellphones_on, $reminder_time, $stathresholdsref, $newalarmref, $significantchangeref); 
$alarmclass		= $pfobjectref->{'ALARMCLASS'};
$alarmname		= $pfobjectref->{'ALARMNAME'};
$msgdir			= $pfobjectref->{'MESSAGE_DIR'};
$msgpfdir		= $pfobjectref->{'MESSAGE_PFDIR'};
$volc_name		= $pfobjectref->{'VOLC_NAME'};
$volc_code		= $pfobjectref->{'VOLC_CODE'};
$auth_subset		= $pfobjectref->{'AUTH_SUBSET'};
$twin			= $pfobjectref->{'TIMEWINDOW'};
$reminders_on		= $pfobjectref->{'reminders_on'};
$escalations_on		= $pfobjectref->{'escalations_on'};
$cellphones_on		= $pfobjectref->{'cellphones_on'};
$reminder_time		= $pfobjectref->{'REMINDER_TIME'};
$stathresholdsref	= $pfobjectref->{'BELLWETHERS'};
$newalarmref		= $pfobjectref->{'new_alarm'};
$significantchangeref	= $pfobjectref->{'significant_change'};

ok(defined $alarmclass, "alarmclass\n");
print STDERR "alarmclass = $alarmclass\n";
ok(defined $alarmname, "alarmname\n");
print STDERR "alarmname = $alarmname\n";
ok(defined $twin, "timewindow\n");
print STDERR "twin = $twin\n";
ok(defined $volc_name, "volc_name\n");
print STDERR "volc_name = $volc_name\n";
ok(defined $auth_subset, "auth_subset\n");
print STDERR "auth_subset = $auth_subset\n";
ok(defined $stathresholdsref, "stathresholdsref\n");
ok(defined $newalarmref, "newalarmref\n");
ok(defined $significantchangeref, "significantchangeref\n");


# how many hits per station?  
print STDERR "\nTesting countStationHits\n";
my $dbname = "t/data/quakes";
my @stations = keys %{$stathresholdsref}; 
my $startTime =  str2epoch("2009-04-20 22:00:00");
my $endTime =  str2epoch("2009-04-21 00:00:00");  
ok(-e $dbname, "Cannot find $dbname\n");                    
my %staHits = countStationHits($dbname, $startTime, $endTime, @stations);  
ok(%staHits, "countStationHits: staHits\n");
printf STDERR "startTime = %s, endTime = %s\n",epoch2str($startTime, '%Y-%m-%d %H:%M'),epoch2str($endTime, '%Y-%m-%d %H:%M');
print STDERR "stations = @stations\n";
print STDERR "staHits = ".(values %staHits) . " \n";
          
# load the events into time & Ml arrays
print STDERR "\nTesting loadEvents\n";
my (@eventTime, @Ml, %currentStats);
ok(loadEvents($dbname, $startTime, $endTime, $auth_subset, \@eventTime, \@Ml, \%currentStats), "loadEvents");
ok($#eventTime > -1, "loadEvents: eventTime array");
ok($#Ml > -1, "loadEvents: Ml array");
print STDERR "Ml: @Ml\n";
ok(defined($currentStats{'events_located'}), "loadEvents: events_located"); 
foreach (keys %currentStats) {
	printf STDERR "%s=>%s\n",$_,$currentStats{$_};
}
    

# compute statistics for this timewindow
print STDERR "\nTesting swarmStatistics\n";
ok(swarmStatistics(\@eventTime, \@Ml, $twin, \%currentStats), "swarmStatistics"); 
ok(defined($currentStats{'cum_ml'}), "swarmStatistics: cum_ml");
foreach (keys %currentStats) {
	printf STDERR "%s=>%s\n",$_,$currentStats{$_};
}  

# get the path to the last message pf of this alarmname
print STDERR "\nTesting getPrevMsgPfPath\n";
my $alarmdb = "t/data/dbalarm";
my ($ldir, $ldfile, $msgTime, $lalarmkey) = getPrevMsgPfPath($alarmdb, $alarmname);  
ok(defined($ldir), "getPrevMsgPfPath: ldir");
mok(defined($msgTime), "getPrevMsgPfPath: ldir");
printf STDERR "ldir = $ldir, ldfile = $ldfile, msgTime = %s\n",epoch2str($msgTime, '%Y-%m-%d %H:%M');

# read the message pf file to get previous thresholds
print STDERR "\nTesting getSwarmParams\n";
my $prevmsgpfdir = "t/data/msgpf";
my $prevmsgpfdfile = "200904202000.pf";
my %prev = getSwarmParams($prevmsgpfdir, $prevmsgpfdfile);
ok(%prev, "getSwarmParams");
foreach (keys %prev) {
	printf STDERR "%s=>%s\n",$_,$prev{$_};
}

# compose the message to send
print STDERR "\nTesting composeMessage\n";
my $msgType = "reminder";
my $txt = composeMessage($msgType, \%currentStats,  $startTime, $endTime, $dbname, \@stations);   
ok(defined($txt), "composeMessage");
print STDERR "txt = $txt\n";

# get the path to put this message to
print STDERR "\nTesting getMessagePath\n";
my ($mdir, $mdfile) = getMessagePath($msgTime);
ok(defined($mdir), "getMessagePath");
print STDERR "$mdir/$mdfile\n";

# get the path to put this message pf to
print STDERR "\nTesting getMessagePfPath\n";
my ($mpfdir, $mpfdfile) = getMessagePfPath($msgTime);
ok(defined($mpfdir), "getMessagePfPath: $mpfdir/$mpfdfile");
print STDERR "$mpfdir/$mpfdfile\n";

# write out the message pf
print STDERR "\nTesting putSwarmParams\n";
foreach (keys %currentStats) {
	printf STDERR "%s=>%s\n",$_,$currentStats{$_};
}
ok(putSwarmParams($mpfdir, $mpfdfile, %currentStats), "putSwarmParams"); 
system("cat $mpfdir/$mpfdfile");

# write out the message
print STDERR "\nTesting writeMessage\n";
ok(writeMessage($mdir, $mdfile, $txt),"writeMessage");   
system("cat $mdir/$mdfile");                                                

# write the alarms row
print STDERR "\nTesting writeAlarmsRow\n";
my $alarmid = 99999; 
my $alarmkey = 99999;
my $alarmtime = now();
my $subject = "Reminder: swarm at $volc_name continuing";
ok(writeAlarmsRow($alarmdb, $alarmid, $alarmkey, $alarmclass, $alarmname, $alarmtime, $subject, $mdir, $mdfile), "writeAlarmsRow");  

# write the alarmcache row
print STDERR "\nTesting writeAlarmcacheRow\n";
ok(writeAlarmcacheRow($alarmdb, $alarmid, $mpfdir, $mpfdfile), "writeAlarmcacheRow");

# compute the median
print STDERR "\nTesting median\n";
my @values = qw(1 7 8 9);
my $median = median(@values);
ok(defined($median), "median");       
print STDERR "median: $median\n";                   

# run a command at the command line
print STDERR "\nTesting runCommand\n";
my $cmd = "ls -l";
my $mode = 1;
my $result = runCommand($cmd, $mode);   
ok(defined($result), $result);
