#!/usr/bin/perl -w
# this script runs every minute via cronjob
# it checks for new files in ../done/
# (new files are put into this dir by the CGI designed for curators
# to run the ftp automatically after they are done uploading their files.)
# if there are new files, it runs 04formEntityTable.pl and
# 05ftpAndEmailDjs.pl and then deletes the file in ../done/

# make sure only one instance of the script is running at a time
use Fcntl 'LOCK_EX', 'LOCK_NB';
exit(0) unless(flock DATA, LOCK_EX|LOCK_NB);
# put your code here instead of sleep
#sleep(60); 

use strict;

my $done_dir  = "../done/";
my @done_files = <$done_dir/*>;

# exit if there are no files in this dir.
if (scalar(@done_files) == 0) {
    exit(0);
}

my $html_dir   = "../html/";
my $linked_xml_dir = "../linked_xml/";

my $entity_table_script = "./04formEntityTable.pl";
my $ftp_email_script    = "./05ftpAndEmailDjs.pl";

for my $done_file (@done_files) {
    # get the genetics ID
    $done_file =~ /(\d+)/;
    my $id = $1;
    my $html_id = $id . ".html";
    my @html_files = <$html_dir/$html_id>;

    for my $html_file (@html_files) {
#        my @args = ($entity_table_script, $html_file, $linked_xml_dir);
	my @args = ("$entity_table_script --input-file $html_file");
        print "@args\n";
        system(@args) == 0 or die("Could not run entity table script: $!\n");
    }

    # re-run the ftp_email_script on the new IDs
    my @linked_xml_files = <$linked_xml_dir/*$id*>; # should only be one file
    if (scalar(@linked_xml_files) > 1) {
        warn "Multiple files with id = $id exist in $linked_xml_dir\n";
    }
    for my $linked_xml_file (@linked_xml_files) { # runs only once
        my @args = ($ftp_email_script, $linked_xml_file);
        system(@args) == 0 or die("Trouble running $ftp_email_script for $id\n");
    }

    # delete the file in done dir after linking is done
    print "deleting the done file\n";
    my @args = ("rm", "-f", $done_file);
    system(@args) == 0 or die("Could not delete $done_file\n");
}

__DATA__
