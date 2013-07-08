#!/usr/bin/perl -w
# Forms the entity table, given a linked XML file

# make sure only one instance of the script is running at a time
use Fcntl 'LOCK_EX', 'LOCK_NB';
exit(0) unless(flock DATA, LOCK_EX|LOCK_NB);
# put your code here instead of sleep
#sleep(60); 

use strict;
use lib "./perlmodules/";
use TextpressoSystemTasks;
use TextpressoGeneralTasks;
use WormbaseLinkTasks;
use lib "../../perlmodules/";
use GeneralTasks;
use GeneralGlobals;

# file specs
if (@ARGV < 2) { 
    die "USAGE: $0 <input linked HTML file> <linked XML dir>\n".
        "eg: $0 ../html/110270.html ../linked_xml/\n";
}
my $htmlfile = $ARGV[0];
my $linkedxmldir = $ARGV[1];

# log file
$htmlfile =~ /(\d+)/;
my $file_id = $1;
my $log_file = "../logs/$file_id";
if (-e $log_file) {
    die "log file $log_file already exists. Won't run again!\n";
}

# (1) copy HTML file to linked XML dir with .XML extn
my @e = split(/\//, $htmlfile);
my $htmlfilename = pop @e;
(my $xmlfilename = $htmlfilename) =~ s/\.html/\.XML/i;
my $xmlfile = $linkedxmldir . "/" . $xmlfilename;
#my @args = ("cp", $htmlfile, $xmlfile);
#system(@args) == 0 or die "died: could not copy $htmlfile to $xmlfile: $!\n";
#print "copied $htmlfile to $xmlfile\n";
GeneralTasks::create_linked_xml_file($htmlfile, $xmlfile);

# (2) form entity table
print "forming entity table...\n";
my $entity_table_file = "../entity_link_tables/$htmlfilename";
my $wbpaper_id = WormbaseLinkTasks::getWbPaperId($xmlfilename);

undef($/); open (IN, "<$xmlfile") or die $!;
my $linked_xml = <IN>; close (IN); $/ = "\n";

my $xml_format = WormbaseLinkTasks::getXmlFormat($xmlfile);
WormbaseLinkTasks::formEntityTable($linked_xml, $xml_format, $wbpaper_id, $entity_table_file, $log_file, "post QC");
print "Entity table available in $entity_table_file\n";

print "DONE.\n";

__DATA__
