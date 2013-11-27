#!/usr/bin/perl -w
use File::Slurp;
use strict;

##########################################################################################
# Following classes come from acedb database on spica:
# Anatomy_name Clone Rearrangement Strain Variation
my @args = ("scp", 
            "citpub\@spica.caltech.edu:/home/citpub/arun/wb_entities/known_entities/Variation",
            "/home/arunr/gsa/worm/known_entities/Variation"
           );
system(@args);
# remove WBVar entries
my $variation_file = "/home/arunr/gsa/worm/known_entities/Variation";
my @variations = read_file($variation_file);
my @variation_data;
foreach my $variation_line (@variations)
    {
    next if $variation_line =~ m{^WBVar};
    next if $variation_line =~ m{^cewivar};
    push @variation_data, $variation_line;
}
write_file($variation_file, @variation_data);
#
@args = ("scp",
            "citpub\@spica.caltech.edu:/home/citpub/arun/wb_entities/known_entities/Clone",
            "/home/arunr/gsa/worm/known_entities/Clone"
           );
system(@args);
@args = ("scp",
            "citpub\@spica.caltech.edu:/home/citpub/arun/wb_entities/known_entities/Strain",
            "/home/arunr/gsa/worm/known_entities/Strain"
           );
system(@args);
@args = ("scp",
            "citpub\@spica.caltech.edu:/home/citpub/arun/wb_entities/known_entities/Rearrangement",
            "/home/arunr/gsa/worm/known_entities/Rearrangement"
           );
system(@args);
@args = ("scp",
            "citpub\@spica.caltech.edu:/home/citpub/arun/wb_entities/known_entities/Anatomy_name",
            "/home/arunr/gsa/worm/known_entities/Anatomy_name"
           );
system(@args);

##########################################################################################
# Genes and Transgenes from postgres on tazendra
#@args = ("scp", 
#         "acedb\@tazendra.caltech.edu:/home/acedb/arun/wb_entities/known_entities/\*",
#         "/home/arunr/gsa/worm/known_entities/"
#        );
#system(@args) == 0 or die("Could not scp file from tazendra\n");

@args = ("perl", "./01_01gene.pl");
system(@args) == 0 or die("Could not run perl script for Gene\n");
@args = ("perl", "./01_02transgene.pl");
system(@args) == 0 or die("Could not run perl script for Transgene\n");

##########################################################################################
# phenotypes update - this is a separate pipeline
#@args = ("./update_phenotypes.pl");
#system(@args) == 0 or die("could not run phenotype script: $!\n");

my $cvsurl = "http://caltech.wormbase.org/cvsweb/PhenOnt/PhenOnt.obo";
my $phenotype_file = "../known_entities/Phenotype";

# get already existing phenotypes
my %old_phenotypes = ();
open(IN, "<$phenotype_file") or die($!);
while (my $line = <IN>) {
    chomp($line);
    (my $phen, my $id) = split(/\t/, $line);
    $old_phenotypes{$phen} = 1;
}
close(IN);

# download current phenotype data
my $cvs_content = getwebpage($cvsurl);
$cvs_content =~ m#<a href=\"(.+?)\" class=\"download-link\">download</a>#;
my $current_url = "http://caltech.wormbase.org" . $1;
my $content = getwebpage($current_url);
my @lines = split(/\n/, $content);

# append only new phenotypes to phenotype_file
open(OUT, ">>$phenotype_file") or die("died: could not append to $phenotype_file: $!");
my $id = "";
my $phen = "";
my %new_phenotypes = ();
my $count = 0;
for my $line (@lines) {
    if ($line =~ /^id:\s*(WBPhenotype:\d+)$/) {
        $id = $1;
        next;
    #} elsif ($line =~ /^synonym: \"([A-Za-z]{3})\" BROAD three_letter_name/) {
    } elsif ($line =~ /^synonym: \"(.+?)\" BROAD three_letter_name/) {
        my $phen = $1;
        
        # just in case there are any spaces before or after the phenotype
        $phen =~ s/^\s+//;
        $phen =~ s/\s+$//;
        
        if (not defined($old_phenotypes{$phen})) {
            print OUT "$phen\t$id\n";
            $count++;
        }
    }
}
close(OUT);
print "$count new phenotypes added to $phenotype_file\n";

sub getwebpage{

    my $u = shift;
    my $page = "";
    use LWP::UserAgent;
    
    my $ua = LWP::UserAgent->new(timeout => 30); # instantiates a new user agent
    my $request = HTTP::Request->new(GET => $u); # grabs url
    my $response = $ua->request($request);       # checks url, dies if not valid.
    
    $page = $response->content;    #splits by line

    return $page;
}
