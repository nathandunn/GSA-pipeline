#!/usr/bin/perl -w

# Provided with a linked XML file, generate
# a table of linked entities for testing.

use strict;
use FindBin qw/$Bin/;
use Getopt::Long;
use lib "$Bin/../perlmodules";
use WormbaseLinkTasks;
use GeneralTasks;

my ($input_file,$output,$help);
GetOptions( 'input-file=s'      => \$input_file,
	    'output-directory=s'=> \$output,
	    'help'              => \$help);

unless ($html && $output) {
    die <<USAGE;
USAGE: $0 --input-file <full path to linked XML file> --output-directory <directory for output files>

    Omit --output to retain consistency with old-style clutter strategy.

   eg: $0 --input-file ../gen110270_fin.html --output output/

# In an ideal world where the input/output is sane...
#   The output/ directory will contain two subdirectories:
#       linked_xml/  - linked xml files
#       entity_reports/ - entity report files in html

USAGE
;
}

# For backwards compatability with the old pipeline,
$output ||= "$Bin/../";

my $elf = WormbaseLinkTasks->new({ stage      => 'post QC',
				   output     => $output,
				   input_file => $html,
				 });


# Why?
GeneralTasks::create_linked_xml_file($elf->html_filepath, $elf->xml_filepath);

$elf->build_entity_report();

print "Entity table available in " . join('/',$elf->reports_directory,$elf->html_filename) . "\n";
print "DONE.\n";
