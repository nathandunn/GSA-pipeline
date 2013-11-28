#!/usr/bin/perl -w

# Provided with a linked XML file, generate
# a table of linked entities for testing.

use strict;
use FindBin qw/$Bin/;
use lib "$Bin/../perlmodules";
use WormbaseLinkTasks;
use GeneralTasks;
use Getopt::Long;

use constant STAGE => 'post-qaqc-04formEntityTable';

my ($input_file,$output_dir,$help);
GetOptions( 'input-file=s'=> \$input_file,
	    'output-dir=s'=> \$output_dir,
	    'help'        => \$help);

if ($help || !$input_file) {
    die <<USAGE;

USAGE: $0 --input-file <full path to linked XML file>

  Required options:
     --input-file   full or relative path to linked XML file.
                    eg: ../html/110270.html (actually XML!!)

  Options:
     --output-dir  directory for output files. Default: ../linked_xml

USAGE
;
}

#'

# For backwards compatability with the old pipeline
$output_dir ||= "$Bin/../linked_xml";

my $elf = WormbaseLinkTasks->new({ stage      => STAGE,
#				   output-dir => $output_dir,  # output-dir not actually used by module yet
				   input_file => $input_file,
				 });


# This basically strips some of the (html) from the XML file.
#GeneralTasks::create_linked_xml_file($elf->html_filepath, $elf->xml_filepath);

my $filename = $elf->filename_base;
GeneralTasks::create_linked_xml_file($elf->input_file,"$output_dir/$filename.xml");

$elf->build_entity_report();

# This belongs in the build_entity_report method.
print "    " . STAGE . " entity table available at " 
    . join('/',$elf->entity_reports_directory,$filename . '-' . STAGE . '.html') . "\n";

print "DONE.\n";

exit (0);
