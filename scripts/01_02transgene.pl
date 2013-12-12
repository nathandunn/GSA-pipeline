#!/usr/bin/perl

use strict;
use diagnostics;
use DBI;
use FindBin qw/$Bin/;
use Encode qw( from_to is_utf8 );

my $dbh = DBI->connect ( "dbi:Pg:dbname=testdb;host=131.215.52.76", "acedb", "") or die "Cannot connect to database!\n";

#my $dir = '/data1/Users/arunr/gsa/worm';
#chdir ($dir) or die "Cannot change to $dir : $!";


my $outfile = "$Bin/../data/known_entities/Transgene";
open (OUT, ">$outfile") or die($!);

# print "Processing trp_name...\n";
my $result = $dbh->prepare( "SELECT DISTINCT trp_publicname FROM trp_publicname" );
$result->execute() or die "Cannot prepare statement: $DBI::errstr\n";
while (my @row = $result->fetchrow) {
  next if ($row[0] =~ /(WBPaper|pmid|cgc)/);

  if ($row[0]) {
    print OUT "$row[0]\n";
  }
}
close(OUT);

# print "Output stored in $outfile\n";

