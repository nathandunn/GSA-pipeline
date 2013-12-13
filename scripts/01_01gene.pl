#!/usr/bin/perl

use strict;
use diagnostics;
use DBI;
use FindBin qw/$Bin/;
use Encode qw( from_to is_utf8 );

my $dbh = DBI->connect ( "dbi:Pg:dbname=testdb;host=131.215.52.76", "acedb", "") or die "Cannot connect to database!\n";

#my $dir = '/data1/Users/arunr/gsa/worm';
#chdir ($dir) or die "Cannot change to $dir : $!";

open (OUT, ">$Bin/../data/known_entities/Gene");

# print "Processing genesequencelab...\n";
my $result = $dbh->prepare( "SELECT * FROM gin_genesequencelab" );
$result->execute() or die "Cannot prepare statement: $DBI::errstr\n";
while (my @row = $result->fetchrow) {
  if ($row[0]) {
    print OUT "$row[0]\n";
  }
}

# print "Processing locus...\n";
$result = $dbh->prepare( "SELECT * FROM gin_locus" );
$result->execute() or die "Cannot prepare statement: $DBI::errstr\n";
while (my @row = $result->fetchrow) {
  if ($row[0]) {
    print OUT "$row[1]\n";
  }
}

# print "Processing seqname...\n";
$result = $dbh->prepare( "SELECT * FROM gin_seqname" );
$result->execute() or die "Cannot prepare statement: $DBI::errstr\n";
while (my @row = $result->fetchrow) {
  if ($row[0]) {
    print OUT "$row[1]\n";
  }
}

# print "Processing sequence...\n";
$result = $dbh->prepare( "SELECT * FROM gin_sequence" );
$result->execute() or die "Cannot prepare statement: $DBI::errstr\n";
while (my @row = $result->fetchrow) {
  if ($row[0]) {
     print OUT "$row[1]\n";
  }
}

# print "Output stored in ./known_entities/Gene\n";

