#!/usr/bin/perl -w
# this script runs every minute via cronjob
# it checks for new files in ../rerun_linking/
# (new files are put into this dir by the CGI designed for Karen
# to re-run the linking script.)
# if there are new files, it runs 02formSortedLexicon.pl and
# 03link.pl and then deletes the file in ../rerun_linking/

use strict;

my $rerun_dir  = "../rerun_linking/";
my @rerun_files = <$rerun_dir/*>;

# exit if there are no files in this dir.
if (scalar(@rerun_files) == 0) {
    exit(0);
}

my $in_xml_dir = "../incoming_xml/";
my $html_dir   = "../html/";

my $lexicon_script = "./02formSortedLexicon.pl";
my $linking_script = "./03link.pl";

my $count = 0;

for my $rerun_file (@rerun_files) {
    # get the genetics ID
    $rerun_file =~ /(\d+)/;
    my $id = $1;

    # re-create the lexicon bcos there are new entities in the journal
    # first pass form
    if ($count == 0) {
        print "Recreating the lexicon...\n";
        my @args = ($lexicon_script);
        system(@args) == 0 or die("Could not run lexicon forming script: $!\n");
        $count++;
    }

    # re-run the linking script on the new IDs
    my @in_xml_files = <$in_xml_dir/*$id*>; # should only be one file
    if (scalar(@in_xml_files) > 1) {
        warn "Multiple files with id = $id exist in $in_xml_dir\n";
    }
    for my $in_xml_file (@in_xml_files) { # runs only once
        print "relinking article $in_xml_file\n";
#        my @args = ("./03link.pl", $in_xml_file, $html_dir);
        my @args = ("./03link.pl --input-dir $in_xml_file --output-dir $html_dir");
        system(@args) == 0 or die("Trouble running $linking_script for $id\n");
    }

    # delete the file in rerun dir after linking is done
    print "deleting the rerun file\n";
    my @args = ("rm", "-f", $rerun_file);
    system(@args) == 0 or die("Could not delete $rerun_file\n");
}
