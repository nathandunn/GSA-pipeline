#!/usr/bin/perl -w

# Generate a table of linked entities for testing.

# make sure only one instance of the script is running at a time
use Fcntl 'LOCK_EX', 'LOCK_NB';
exit(0) unless(flock DATA, LOCK_EX|LOCK_NB);
# put your code here instead of sleep
#sleep(60); 

use strict;
use lib "./perllib";
use TextpressoSystemTasks;
use TextpressoGeneralTasks;
use WormbaseLinkTasks;
use GeneralTasks;
use GeneralGlobals;
use GetOptions::Long;

my ($html_filepath,$xml_directory);
GetOptions ( 'html_filepath=s' => $html_filepath,
	     'xml_directory=s' => $xml_directory );

unless ($html_filepath && $xml_directory) {
    die <<USAGE;
USAGE: $0 --html_filepath <full path to linked HTML file> --xml_directory <linked XML directory>
   eg: $0 ../html/gen110270_fin.html ../linked_xml/
USAGE
;
}



my $agent = WormbaseLinkTasks->new({ stage         => 'post QC',
				     xml_directory => $xml_directory,
				     html_filepath => $html_hilepath,
				   });
# I don't have this methof
GeneralTasks::create_linked_xml_file($agent->html_filepath, $agent->xml_path);

print "forming entity table...\n";

# Could probably create this dynamically
my $output_file   = "../entity_link_tables/" . $agent->html_filename;


# Slurp up linked xml
undef($/); open (IN, "<" . $agent->xml_filepath) or die $!;
my $linked_xml = <IN>; close (IN); $/ = "\n";

$agent->linked_xml($linked_xml);  # worth storing it?

# I don't know where this method is yet.
my $xml_format = WormbaseLinkTasks::getXmlFormat($agent->xml_filepath);


$agent->form_entity_table({xml_format   => $xml_format,
			   output_file  => $output_file,
			  });


print "Entity table available in $output_file\n";
print "DONE.\n";
