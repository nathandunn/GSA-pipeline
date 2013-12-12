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

use constant STAGE      => 'first-pass';
use constant CREATED_BY => '03link.pl';

my ($input_dir,$help);
GetOptions( 'input-dir=s'  => \$input_dir,
	    'help'         => \$help);

if ($help) {
    die <<USAGE;

USAGE: $0

    NOTE!  The input/output dirs should all probably be relocated.

  Optional parameters:
  --input-dir   path to incoming xml (default: $Bin\/..\/incoming_xml).

USAGE
;
}

# Both of these should be moved to a
# top-level input/output directories.
$input_dir  ||= "$Bin/../incoming_xml";
# TH: Vestigial. From bizarro logic in GeneralTasks.
my $output_dir ||= "$Bin/../html";

# TH: getNewFiles doesn't work. Uniquifying.
my %seen;
my @xmlfiles = grep {!$seen{$_}++ } GeneralTasks::getNewFiles($input_dir, $output_dir);

for my $input_file (@xmlfiles) {
    # Elves do all the heavy lifting.
    # OO programming is like magic!
    my $elf = WormbaseLinkTasks->new({ stage        => STAGE,
				       input_file   => $input_file,
				     });

    $elf->log->info("Running script $0 for " . $elf->filename);

    $elf->log->info("...getting xml format via GeneralTasks::getXMLFormat");
    my $xml_format = GeneralTasks::getXmlFormat($input_file);
        
    # pre-processing
    $elf->log->info("...converting line endings GeneralTasks::convertDosFileToUnixFile");
    GeneralTasks::convertDosFileToUnixFile($input_file);
    
    my @lines = ();
    open (IN, "<$input_file") or $elf->log->die("Died. Input file $input_file not found.");
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

    $elf->log->info("...finding and linking objects in XML");
    $elf->linked_xml($elf->findAndLinkObjects($xml_contents, 
					      $tokenized_contents, 
					      $xml_format));
    
    # TH: This was previously placed in ../html and called .html
    #    even though it is NOT html.
    # Now it goes in
    #    output/CLIENT/ID/ID-linked.xml
    my $marked_up_xml = join('/',
			     $elf->stage_directory,
			     $elf->filename . '-linked.xml');
    
    # write output
    open (OUT, ">$marked_up_xml") or $elf->log->die ("could not open $marked_up_xml for writing!\n");
    print OUT $elf->linked_xml;
    close (OUT);

    # Copy the original file to the output directory
    system("cp $input_file " . $elf->stage_directory . "/.") 
	or $elf->log->warn("problem copying $input_file to " . $elf->stage_directory);

    # Change permissions for the html file so that curators can edit it
    chmod 0755, $marked_up_xml;

    $elf->log->info("...done. Output file is available in $marked_up_xml");
    
    # Create the first pass entity table.
    $elf->build_entity_report();
    
    # Send an email to interested parties.
    my $gsa_id  = $elf->file_id;
    my $subject = "GSA WB $gsa_id linked file available";

    my $base_url = GeneralGlobals::BASE_URL;
    my $body = <<END;

  Linked file available for manual QAQC at
      $base_url/cgi-bin/gsa/worm/edit.pl?docid=$gsa_id
  
  The entity table for this first pass/automatically linked article is available at
  
      $base_url/gsa/worm/$gsa_id-report.html

  Thank you and party on, Wayne.

END


# Get senders/receivers
my $email_sender    = $elf->email_sender;
    my @email_receivers = $elf->email_receivers;
    
    for my $receiver (@email_receivers) {
        print "Sending email for confirmation: $receiver\n";
#        GeneralTasks::mailer($email_sender, $receiver, $subject, $body);
    }
    $elf->log->info("Done!");
}



exit(0);

__DATA__
