#!/usr/bin/perl -w

# Provided with a linked XML file, generate
# a table of linked entities for testing.

use strict;
use FindBin qw/$Bin/;
use lib "$Bin/../perlmodules";
use WormbaseLinkTasks;
use GeneralTasks;
use Getopt::Long;

use constant STAGE => 'post-qaqc';
use constant CREATED_BY => '04formEntityTable.pl';

my ($input_file,$output_dir,$help);
GetOptions( 'input-file=s'=> \$input_file,
	    'output-dir=s'=> \$output_dir,
	    'help'        => \$help);

if ($help || !$input_file) {
    die <<USAGE;
    
  USAGE: $0 --input-file <full path to linked XML file>
      
      REQUIRED options:
      --input-file   full or relative path to linked XML file.
    
      eg: ../output/GSA/110270/110270-linked.xml

USAGE
;

}

my $elf = WormbaseLinkTasks->new({ stage      => STAGE,
				   input_file => $input_file,
				 });


# This basically strips some of the (html) from the XML file.
#GeneralTasks::create_linked_xml_file($elf->html_filepath, $elf->xml_filepath);

my $filename = $elf->filename_base;
my $stage_directory = $elf->stage_directory;

GeneralTasks::create_linked_xml_file($elf->input_file,"$stage_directory/$filename-cleaned.xml");

$elf->build_entity_report();


exit (0);
