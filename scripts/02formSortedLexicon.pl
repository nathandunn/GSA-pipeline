#!/usr/bin/perl -w
# This script keeps the lexicon up to date with wormbase

use strict;
use lib "./perlmodules/";
use TextpressoSystemTasks;
use TextpressoGeneralTasks;
use WormbaseLinkGlobals;

my $known_entities_dir = "../known_entities/";
my $stopwords_file = "./stopwords";
my $exclusions_dir = "../exclusions/";
my $outfile = "lexicon";

my $stopwords = getStopWords($stopwords_file);

# new objects from author form
#my $af_page = "http://tazendra.caltech.edu/~postgres/cgi-bin/journal/journal_all.cgi?action=Show+Data&type=textpresso";
my $af_page = "http://tazendra.caltech.edu/~postgres/cgi-bin/author_fp_display.cgi?afp_jfp=jfp&action=Show+Data&type=textpresso";
my %lexicon = ();
loadLexicon(\%lexicon, $known_entities_dir, $stopwords, $exclusions_dir, $af_page);
my @sorted_entries = ();
sortLexiconEntries(\%lexicon, \@sorted_entries);

print "Outputting to file $outfile...\n";
open (OUT, ">$outfile") or die $!;
for my $entry (@sorted_entries) {
    for my $class (keys %{$lexicon{$entry}}) {
        my $id = $lexicon{$entry}{$class};
        if (!$id) { # entry itself is id
            print OUT "$entry\t$class\n";
        } 
        else {
            print OUT "$entry\t$id\t$class\n";
        }
    } 
}
close OUT;
print "Sorted lexicon loaded in file named $outfile.\n";

sub loadLexicon {
    my $lexicon_ref         = shift;
    my $known_entities_dir  = shift;
    my $stopwords           = shift;
    my $exclusions_dir      = shift;
    
    my $af_page = shift;

    if (1) {
        loadObjectsFromAuthors($af_page, $lexicon_ref);
    }
    else {
        print "\nObjects from author form not loaded. Testing only GO now.\n\n";
    }

    my @files = <$known_entities_dir/*>;
    for my $file (@files) {
        my $object_name = getFileName($file);
        if ($object_name eq "Variation") {
            populateVariation($object_name, $file, $lexicon_ref, $exclusions_dir);
        } else {
            populate($object_name, $file, $lexicon_ref, $stopwords, $exclusions_dir);
            if ($object_name eq "Gene") {
                populateProtein("Protein", $file, $lexicon_ref, $exclusions_dir);
            }
        }
    }
}

sub loadObjectsFromAuthors {
    my $af_page = shift;
    my $lexicon_ref = shift;
    
    print "Loading entities from author form...\n";

    my $af_content = TextpressoGeneralTasks::getwebpage($af_page);
    my @lines = split(/\n/, $af_content);
    my $count = 0;
    for (my $i = 0; $i < @lines; $i++) {
        if ($lines[$i] eq "<tr>") {
            my $doi = $lines[$i+1];
            $doi =~ s/\<.+?\>//g;

            my $obj = $lines[$i+3];
            $obj =~ s/\<.+?\>//g;

            my $data_line = $lines[$i+4];
            $data_line =~ s/\<.+?\>//g;

            # remove invalid data i.e. anything after ~~
            $data_line =~ s/~~.+$//;
            # remove stuff inside [ ]
            $data_line =~ s/\[.+?\]//g;
            # assuming author data is comma-separated
            my @data_entries = split(/\,/, $data_line);

            for my $entry (@data_entries) {
                $entry =~ s/^\s+//;
                $entry =~ s/\s+$//;
                next if ($entry =~ /^$/);

                if ($obj eq "genesymbol") {
                    $lexicon_ref->{$entry}{"Gene"} = "";
                } elsif ($obj eq "extvariation") {
                    $lexicon_ref->{$entry}{"Variation"} = "";
                } elsif ($obj eq "newstrains") {
                    $lexicon_ref->{$entry}{"Strain"} = "";
                } elsif ($obj eq "newbalancers") {
                    $lexicon_ref->{$entry}{"Rearrangement"} = "";
                } elsif ($obj eq "transgene") {
                    $lexicon_ref->{$entry}{"Transgene"} = "";
                } elsif ($obj eq "newsnp") {
                    $lexicon_ref->{$entry}{"Variation"} = "";
                }
                $count++;
            }
        }
    }    

    print "Total # of objects from author form = $count\n";
}
    

sub populateObjectOnly {
    my $entity_class = shift;
    my $file       = shift;
    my $lexicon_ref   = shift;
    my $exclusions_dir = shift;

    print "Loading class: $entity_class ...\n";

    my $exclusion_file = $exclusions_dir . '/' . $entity_class;
    my %exclusion_list = ();
    open (IN, "<$exclusion_file"); #or print ("No exclusion file for $entity_class\n");
    while (<IN>) {
        chomp;
        $exclusion_list{$_} = 1;
    }
    close (IN);

    open (IN, "<$file") or die ("cannot open input file $file for reading.");
    while (my $entry = <IN>) {
        chomp($entry);

        my @e = split(/\t/, $entry); # entry is like 'Christopher G. Proud\tWBPerson10232'
                                     # or like 'Jud\tWBPhenotype:0001612' 
        $entry = $e[0];

        # exclude only first names like John, Don, Kim
        if ( ($entity_class eq 'Person') && ($entry !~ / /) ) {
            next;
        }

        next if (defined($exclusion_list{$entry}));

        # $entry = ReplaceSpecChar($entry);
        $lexicon_ref->{$entry}{$entity_class} = "";
    }
    close (IN);

    return;
}

sub populate {
    my $entity_class = shift;
    my $file       = shift;
    my $lexicon_ref   = shift;
    my $stopwords  = shift;
    my $exclusions_dir = shift;

    print "Loading class: $entity_class ...\n";

    my $exclusion_file = $exclusions_dir . '/' . $entity_class;
    my %exclusion_list = ();
    my $status = open (IN, "<$exclusion_file");
    if (not $status) {
        #print ("(No exclusion file for $entity_class)\n");
    } else {
        while (<IN>) {
            chomp;
            $exclusion_list{$_} = 1;
        }
        close (IN);
    }

    open (IN, "<$file") or die ("cannot open input file $file for reading.");
    while (my $line = <IN>) {
        chomp($line);

        my ($entity, $id);
        if ($line =~ /^(.+?)\t(.+)$/) {
            $entity = $1;
            $id     = $2;
        } else {
            $entity = $line;
            $id     = "";
        }

        # exclude single letter objects
        next if ($entity =~ /^.$/); 
        next if ($entity =~ /edited/);
        # exclude stopwords
        next if ($entity =~ /^$stopwords$/i);

        # $entity = ReplaceSpecChar($entity);
        next if (defined($exclusion_list{$entity}));

        $lexicon_ref->{$entity}{$entity_class} = $id;
    }
    close (IN);

    return;
}

sub populateProtein { # capitalized genes
    my $entity_class = shift;
    my $file       = shift;
    my $lexicon_ref   = shift;
    my $exclusions_dir = shift;

    my $exclusion_file = $exclusions_dir . '/' . $entity_class;
    my %exclusion_list = ();

    print "Loading $entity_class"."s...\n";

    my $status = open (IN, "<$exclusion_file");
    if (not $status) {
        #print ("(No exclusion file for $entity_class)\n");
    } else {
        while (<IN>) {
            chomp;
            $exclusion_list{$_} = 1;
        }
        close (IN);
    }

    open (IN, "<$file") or die ("cannot open input file $file for reading.");
    while (my $entry = <IN>) {
        chomp($entry);
        next if (defined($exclusion_list{$entry}));
        if ($entry =~ /[a-z]/) { # if gene is all caps, then no need to put in protein
            if ($entry =~ /([a-z]{2})([a-z])(-\d+)/) {
                my $temp1 = $1;
                my $temp2 = $2;
                my $temp3 = $3;
                $temp2 = uc($temp2);
                my $new_entry = $temp1 . $temp2 . $temp3;
                $lexicon_ref->{$new_entry}{$entity_class} = "";
            }
            
            $entry = uc($entry);
            # $entry = ReplaceSpecChar($entry);
            $lexicon_ref->{$entry}{$entity_class} = "";
        }
    }
    close (IN);

    return;
}

sub populateVariation {
    my $entity_class = shift;
    my $file       = shift;
    my $lexicon_ref   = shift;
    my $exclusions_dir = shift;

    my $exclusion_file = $exclusions_dir . '/' . $entity_class;
    my %exclusion_list = ();
    open (IN, "<$exclusion_file"); # or print ("(No exclusion file for $entity_class)\n");
    while (<IN>) {
        chomp;
        $exclusion_list{$_} = 1;
    }
    close (IN);


    print "Loading $entity_class"."s...\n";

    open (IN, "<$file") or die ("cannot open input file $file for reading.");
    while (my $entry = <IN>) {
        chomp($entry);
        next if (defined($exclusion_list{$entry}));
        # $entry = ReplaceSpecChar($entry);
        $lexicon_ref->{$entry}{$entity_class} = "";
        for my $suffix ( @{(WormbaseLinkGlobals::SY_ALLELE_SUFFIXES)} ) {
            my $variant = $entry . $suffix;
            $lexicon_ref->{$variant}{$entity_class} = "";
        } 
    }
    close (IN);

    return;
}

sub sortLexiconEntries {
    print "Sorting lexicon entries...\n";
    my $lexicon_ref = shift;
    my $sorted_entries_ref = shift;
    
    my @entries = keys %$lexicon_ref;
    @$sorted_entries_ref = sort {length($b) <=> length($a)} @entries;

    print " done\n";
    return;
}

sub getFileName {
    my $infile = shift;
    my @e = split(/\//, $infile);
    my $ret = pop @e;
    $ret =~ s/\.\S+$//;
    return($ret);
}

sub getStopWords {
    my $f = shift;
    open (IN, "<$f");
    my $s = '(';
    while (<IN>) {
        chomp;
        $s .= $_ . '|';
    }
    $s =~ s/\|$//;
    $s .= ')';
    return $s;
}
