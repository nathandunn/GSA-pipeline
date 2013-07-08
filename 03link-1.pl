#!/usr/bin/perl
# Does the linking of entities to mod 

# make sure only one instance of the script is running at a time
use Fcntl 'LOCK_EX', 'LOCK_NB';
exit(0) unless(flock DATA, LOCK_EX|LOCK_NB);
# put your code here instead of sleep
#sleep(60); 

use strict;

# the linking scripts have their own perl modules bcos of 
# subtle changes between linking scripts & gsa scripts
use lib "./perlmodules/";
use TextpressoGeneralTasks;
use FlybaseLinkTasks;
use GeneralTasks;
use GeneralGlobals;

# input args
if (@ARGV < 2) {
    print "USAGE: for automatic running.\n".
          "$0 <in XML dir> <HTML dir>\n".
          "eg: $0 ../incoming_xml/ ../html/\n\n";
    print "USAGE: for running manually.\n".
          "$0 <in XML file> <HTML dir>\n".
          "eg: $0 ../incoming_xml/GEN1234567.XML ../html/\n";
    die;
}
my $in       = $ARGV[0];
my $outdir   = $ARGV[1];

my @newfiles = GeneralTasks::getNewFiles($in, $outdir);

# auto email settings
my $sender    = FlybaseLinkTasks::getSender();
my @receivers = FlybaseLinkTasks::getReceivers();
#hmm: introduce send-email flag;
my $send_email = 1;

# load lexicon
my %lexicon = ();
my @sorted_entries = ();

for my $in_xml_file (@newfiles) {
    print "in xml file = $in_xml_file\n";
    my $xml_format = GeneralTasks::getXmlFormat($in_xml_file);

    print "Loading lexicon...\n";
    FlybaseLinkTasks::loadLexicon(\%lexicon, \@sorted_entries, $xml_format);
    print "Lexicon loaded\n";
    
    my @e = split(/\//, $in_xml_file);
    my $filename = pop @e;
    (my $html_filename = $filename) =~ s/\.xml/\.html/i;
    my $out_html_file  = "../html/$html_filename";
    my $reset_html_file = " ../resethtml/$html_filename";

    $filename =~ /(\d+)/; # this will be the GSA ID
    my $gsa_id = $1;

    GeneralTasks::convertDosFileToUnixFile($in_xml_file);

    my @lines = ();
    open (IN, "<$in_xml_file") or die ("Died. Input file $in_xml_file not found.");
    my $xml_contents = "";
    my $tokenized_contents = "";
    while (my $xml_line = <IN>) {
    
        # pre-process xml to capture entities that are incorrectly italicized.
        # eg: <I>w</I><SUP>1118</SUP> should be changed to <I>w<SUP>1118</SUP></I>
        # dont do this, since this is not your problem anyway!
        # $xml_line =~ s/(<I>.+?)(<\/I>)(<SUP>.+?<\/SUP>)/$1$3$2/g;
        
        if ($xml_format eq GeneralGlobals::NLM_XML_ID) {
            $xml_line = FlybaseLinkTasks::replace_NLMxml_tags_with_html_tags($xml_line);
        }
        
        # $xml_contents .= TextpressoGeneralTasks::ReplaceSpecChar($xml_line);
        $xml_contents .= $xml_line;
        next if GeneralTasks::dontLinkLine($xml_line, $xml_format);

        chomp($xml_line);
        
        #my $line = FlybaseLinkTasks::removeXmlStuff($xml_line);
        my $line = $xml_line;
        
        next if ($line eq "");
        # @lines= ($line);
        # my $tokenized_line = TextpressoGeneralTasks::ReplaceSpecChar(@lines);
        my $tokenized_line = $line;
        $tokenized_contents .= $tokenized_line;
    }
    close (IN);

    my ($linked_xml, $ambiguous, $false_negatives) = 
        FlybaseLinkTasks::findAndLinkObjects($xml_contents, 
                                             $tokenized_contents, 
                                             \%lexicon, 
                                             \@sorted_entries, 
                                             $xml_format,
                                             $gsa_id 
                                            );
    
    open (OUT, ">$out_html_file");
    print OUT $linked_xml;
    close (OUT);
    open (OUT, ">$reset_html_file");
    print OUT $linked_xml;
    close (OUT);

    #die "HTML file output. Not running entity table, etc.,\n";

    my $first_pass_entity_table_file = "../first_pass_entity_link_tables/$html_filename";
    $filename =~ /(\d+)/; # this will be the GSA ID
    print "\nForming first pass entity table\n";
    my $first_pass_log_file = "../first_pass_logs/$1";
    FlybaseLinkTasks::formEntityTable( $linked_xml, $xml_format, 
            $first_pass_entity_table_file, $first_pass_log_file, "first pass");

    # change permissions for the html file so that curators can edit it
    my @args = ("chmod", "777", $out_html_file);
    system(@args) == 0 or die("Could not change permissions to 777 for $out_html_file");

    # send email
    if ($send_email) {
	print "Sending email...\n";
	$filename =~ /(\d+)/;
	my $docid = $1;
	my $subject = "GSA $docid linked file available";
	$out_html_file =~ s/^\.\.\///;
	$first_pass_entity_table_file =~ s/^\.\.\///;
	
	my $base_url = GeneralGlobals::BASE_URL;
	my $body = "Linked file available for manual QC at\n".
	    "$base_url/cgi-bin/gsa/fly/edit.pl?docid=$docid\n\n" .
	    "The entity table for this first pass/automatically linked article is available at\n" .
	    "$base_url/gsa/fly/$first_pass_entity_table_file ." ;
	$body .= $ambiguous;
	$body .= $false_negatives;
	for my $receiver (@receivers) {
	    GeneralTasks::mailer($sender, $receiver, $subject, $body);
	  }
    }

    print "Done.\n";

    print "Out file with html extension is in $out_html_file\n\n\n";
    print "\n\nRun 04formEntityTable.pl after all the manual corrections.\n\n";
}
exit(0);


__DATA__
