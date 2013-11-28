#!/usr/bin/perl 

# make sure only one instance of the script is running at a time
use Fcntl 'LOCK_EX', 'LOCK_NB';
exit(0) unless(flock DATA, LOCK_EX|LOCK_NB);
# put your code here instead of sleep
#sleep(60); 

use strict;

# the linking scripts have their own perl modules because of 
# subtle changes between linking scripts & GSA pipeline scripts
use FindBin qw/$Bin/;
use lib "$Bin/../perlmodules";
use TextpressoSystemTasks;   # Oh god, the nightmare of Exporter.
use TextpressoGeneralTasks;
use WormbaseLinkTasks;
use WormbaseLinkGlobals;
use GeneralTasks;
use GeneralGlobals;
use File::Slurp;
use Specs;
use Getopt::Long;

use constant STAGE => 'first-pass-03link';

my ($input_dir,$output_dir,$help);
GetOptions( 'input-dir=s'  => \$input_dir,
	    'output-dir=s' => \$output_dir,
	    'help'         => \$help);

if ($help) {
    die <<USAGE;

USAGE: $0

    NOTE!  The input/output dirs should all probably be relocated.

  Optional parameters:
  --input-dir   path to incoming xml (default: $Bin\/..\/incoming_xml).
  --output-dir  path to place HTML (default: $Bin\/..\/html)

USAGE
;
}

# Both of these should be moved to a
# top-level input/output directories.
$input_dir  ||= "$Bin/../incoming_xml";
$output_dir ||= "$Bin/../html";

# TH: getNewFiles doesn't work. Uniquifying.
my %seen;
my @xmlfiles = grep {!$seen{$_}++ } GeneralTasks::getNewFiles($input_dir, $output_dir);

for my $input_file (@xmlfiles) {
    print "Processing $xmlfile...\n";

    # Elves do all the heavy lifting.
    # OO programming is like magic!
    my $elf = WormbaseLinkTasks->new({ stage        => STAGE,
				       output_dir   => $output_dir,
				       input_dir    => $input_dir,  # actually extractable by filename, was xml_filepath
				       input_file   => $input_file,
				     });

#    warn "hmtl_filename: " . $elf->html_filename . "\n";
#    warn "hmtl_path: " . $elf->html_filepath . "\n";
#    warn "xml_filename: " . $elf->xml_filename . "\n";
#    die;
    
    my $xml_format = GeneralTasks::getXmlFormat($input_file);
        
    # pre-processing
    GeneralTasks::convertDosFileToUnixFile($input_file);
    
    my @lines = ();
    open (IN, "<$input_file") or die ("Died. Input file $input_file not found.");

    my ($xml_contents,$tokenized_contents);
    while (my $xml_line = <IN>) {
        $xml_contents .= $xml_line;
        next if GeneralTasks::dontLinkLine($xml_line, $xml_format);
	
        chomp($xml_line);
        my $line = $elf->removeXmlStuff($xml_line);
        next if ($line eq "");
        $tokenized_contents .= $line;
    }
    close (IN);
    
    $elf->linked_xml($elf->findAndLinkObjects($xml_contents, 
					      $tokenized_contents, 
					      $xml_format));
    
    # for viewing the linked file on a browser
    # NOTE: This is NOT HTML. It is XML!!  -- th
    my $marked_up_xml = "$output_dir/" . $elf->filename_base . '.html';
    
    # write output
    open (OUT, ">$marked_up_xml") or die ("could not open $marked_up_xml for writing!\n");
    print OUT $elf->linked_xml;
    close (OUT);

    # change permissions for the html file so that curators can edit it
    chmod 0755, $marked_up_xml;
#    my @args = ("/bin/chmod", "0777", $out_html_file);
#    system(@args);
    print "\n\nHTML output file is in $marked_up_xml\n";
    
    # first pass entity table
    my $first_pass_entity_table_file = "../first_pass_entity_link_tables/" . $elf->filename_base . '.html';
    print "\nForming first pass entity table in $first_pass_entity_table_file\n";

    my $first_pass_log_file = "../first_pass_logs/$1";
    $elf->build_entity_report();
    
    # email
#    my $gsa_id = $elf->gsa_id;
    my $gsa_id = $elf->filename_base;
    my $subject = "GSA WB $gsa_id linked file available";

    # Why?
#    $out_html_file =~ s/^\.\.\///;
#    $first_pass_entity_table_file =~ s/^\.\.\///;
    
    my $base_url = GeneralGlobals::BASE_URL;
    my $body = "\n" .
	"Linked file available for manual QC at\n" . 
	"$base_url/cgi-bin/gsa/worm/edit.pl?docid=$gsa_id .\n\n" . 
	"The entity table for this first pass/automatically linked article is available at\n" .
	"$base_url/gsa/worm/$first_pass_entity_table_file .\n\n" .
	"Thank you!\n";
    
    # Get senders/receivers
    my $email_sender    = $elf->email_sender;
    my @email_receivers = $elf->email_receivers;
    
    for my $receiver (@email_receivers) {
        print "Sending email for confirmation: $receiver\n";
#        GeneralTasks::mailer($email_sender, $receiver, $subject, $body);
    }
}
exit(0);

__DATA__
