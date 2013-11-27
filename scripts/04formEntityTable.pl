#!/usr/bin/perl -w

# Provided with a linked XML file, generate
# a table of linked entities for testing.

use strict;
use FindBin qw/$Bin/;
use lib "$Bin/../perlmodules";
use WormbaseLinkTasks;
use GeneralTasks;
use Getopt::Long;

my ($html,$output,$help);
GetOptions( 'html-file=s'       => \$html,
	    'output-directory=s'=> \$output,
	    'help'              => \$help);

unless ($html && $output) {
    die <<USAGE;
USAGE: $0 --html-file <full path to linked HTML file> --output-directory <directory for output files>

   NOTE!  --html should simply be renamed to "--input-file" to match the module interface.
   
    Omit --output to retain consistency with old-style clutter strategy.

   eg: $0 --html ../gen110270_fin.html --output output/

   The output/ directory will contain two subdirectories:
       linked_xml/  - linked xml files
       entity_reports/ - entity report files in html

USAGE
;
}

# For backwards compatability with the old pipeline,
$output ||= "$Bin/../";

my $elf = WormbaseLinkTasks->new({ stage      => 'post QC',
				   output     => $output,
				   input_file => $html,
				 });

# Not refactored.
GeneralTasks::create_linked_xml_file($elf->html_filepath, $elf->xml_filepath);

print "forming entity table...\n";

$elf->build_entity_report();

print "Entity table available in " . join('/',$elf->reports_directory,$elf->html_filename) . "\n";
print "DONE.\n";
