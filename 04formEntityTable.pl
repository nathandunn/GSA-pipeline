#!/usr/bin/perl -w

# Generate a table of linked entities for testing.

# make sure only one instance of the script is running at a time
#use Fcntl 'LOCK_EX', 'LOCK_NB';
#exit(0) unless(flock DATA, LOCK_EX|LOCK_NB);
# put your code here instead of sleep
#sleep(60); 

use strict;
use lib ".";
use WormbaseLinkTasks;
use GeneralTasks;
use Getopt::Long;

my ($html,$output,$help);
GetOptions( 'html_in=s'=> \$html,
	    'output=s' => \$output,
	    'help'     => \$help);

unless ($html && $output) {
    die <<USAGE;
USAGE: $0 --html <full path to linked HTML file> --output <directory for output files>
   
   eg: $0 --html ../gen110270_fin.html --output output/

   The output/ directory will contain two subdirectories:
     xml/  - linked xml files
     entity_reports/ - entity report files in html

USAGE
;
}



my $agent = WormbaseLinkTasks->new({ stage         => 'post QC',
				     output        => $output,
				     html_filepath => $html,
				   });

# Not refactored.
GeneralTasks::create_linked_xml_file($agent->html_filepath, $agent->xml_filepath);

print "forming entity table...\n";

$agent->build_entity_report();

print "Entity table available in " . join('/',$agent->reports_directory,$agent->html_filename) . "\n";
print "DONE.\n";
