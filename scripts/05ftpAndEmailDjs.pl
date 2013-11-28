#!/usr/bin/perl -w
use strict;
use lib "./perlmodules/";
use TextpressoSystemTasks;
use TextpressoGeneralTasks;
use WormbaseLinkTasks;
use GeneralTasks;
use GeneralGlobals;

my $sender = WormbaseLinkGlobals::DEVELOPER_EMAIL;
my @receivers = ();
for my $rec ( @{(WormbaseLinkGlobals::FINAL_EMAILS)} ) {
    push @receivers, $rec;
}

# file specs
if (@ARGV < 1) { 
    die "USAGE: $0 <linked XML file>\n".
	    "eg: $0 ../linked_xml/GEN123456.XML\n";
}
my $linkedxmlfile = $ARGV[0];

my $xml_format = GeneralTasks::getXmlFormat( $linkedxmlfile );
if ($xml_format eq GeneralGlobals::NLM_XML_ID) {
    WormbaseLinkTasks::replaceAnchorTagsInLinkedXml( $linkedxmlfile );
}

# get filename
my @e = split(/\//, $linkedxmlfile);
my $linkedxmlfilename = pop @e;

# read ftp, password from file
my $password_file = "../../gsa_ftp_password";
open (IN, "<$password_file") or die ("cannot open input file $password_file for reading.");
    my $gsa_ftp_password = quotemeta(<IN>);
close (IN);
my($user, $password) = split(/\t/, $gsa_ftp_password, 2);
chomp($user);
chomp($password);
$user =~ s/\\//g;
$password =~ s/\\//g;

# FTP linked file to DJS
use Net::FTP;
print "FTPing linked xml file to djs...\n";
my $ftp = Net::FTP->new("ftp1.dartmouthjournals.com", Passive=>1) or die ("Died: Could connect to dartmouth ftp server");
$ftp->login($user, $password) or die ("could not authenticate");
$ftp->cwd("WormBase") or die ("could not change working dir to WormBase\n");
$ftp->put($linkedxmlfile, $linkedxmlfilename) or die ("Could not put file using FTP: $@\n");

# Email DJS with link to entity table
print "Sending email to DJS people...\n";
$linkedxmlfilename =~ /(\d+)/;
my $subject = "FTPed linked file for GSA WB article $1";

my $entity_table_file = "../entity_link_tables/$linkedxmlfilename";
$entity_table_file =~ s/\.XML/\.html/i;
$entity_table_file =~ s/\.\.\///;

my $body = "Linked file has been FTPed to DJS server at ftp://ftp1.dartmouthjournals.com/WormBase/ .\n".
           "The entity table for this article is available at\n".
           "http://textpresso-dev.caltech.edu/gsa/worm/$entity_table_file";
for my $receiver (@receivers) {
    GeneralTasks::mailer($sender, $receiver, $subject, $body);
}

print "DONE.\n";
