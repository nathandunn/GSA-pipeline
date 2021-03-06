package TextpressoSystemTasks;

# Package provide class and methods for
# tasks related to processing and maintaining of
# the build for the Textpresso system.
#
# (c) 2005-8 Hans-Michael Muller, Caltech, Pasadena.
#     with additions by Arun Rangarajan
#


use strict;
use TextpressoGeneralTasks;
use TextpressoSystemGlobals;
use TextpressoGeneralGlobals;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(AddToIndex AddToAnnotationInOneProcess RemoveFromIndex RemoveFromAnnotation Tokenizer SpecialReplacements RemovePreprocessingTags);

sub AddToIndex {
    
    use File::Basename;
    
    my $infile = shift;
    my $outfield = shift;
    my $itype = shift;

    $outfield .= (SY_INDEX_TYPE)->{$itype};
    (my $fname, my $fdir, my $fsuf) = fileparse($infile);
    
    if ($itype eq 'keyword') {
	my %idlist = KeywordParse($infile);
	foreach my $key (keys % idlist) {
	    my $sd1 = substr($key, 0, 1);
	    if (! -d "$outfield$sd1/") {
		mkdir("$outfield$sd1/");
	    }
	    my $outname;
	    if (length($key) > 1) {
		my $sd2 = substr($key, 1, 1);
		if (! -d "$outfield$sd1/$sd2/") {
		    mkdir ("$outfield$sd1/$sd2/");
		}
		$outname = $outfield . $sd1 . '/' . $sd2 . '/' . $key;
	    } else {
		$outname = $outfield . $sd1 . '/LITERAL';
	    }
	    FlushOutToIndexFile ($outname, $fname, \%{$idlist{$key}});
	}
    } elsif ($itype eq 'semantic') {
	my %idlist = AnnotationParse($infile);
	my $pcat = (GE_DELIMITERS)->{parent_category};
	foreach my $cat (keys % idlist) {
	    foreach my $att (keys %{$idlist{$cat}}) {
		if ($att =~ /$pcat/) {
		    my $outname = $outfield . (SY_INDEX_SUBTYPE)->{categories} . $cat;
		    FlushOutToIndexFile ($outname, $fname, \%{$idlist{$cat}{$att}});
		} 
		else {
		    my $sd1 = (SY_INDEX_SUBTYPE)->{attributes} . $cat;
		    if (! -d "$outfield$sd1/") {
			mkdir("$outfield$sd1/");
		    }
		    (my $sd2) = $att =~ /(.+?)=/;
		    if (! -d "$outfield$sd1/$sd2/") {
			mkdir ("$outfield$sd1/$sd2/");
		    }
		    (my $aux) = $att =~ /=\'(.+?)\'/;
		    my @values = split (/\|/, $aux);
		    foreach my $value (@values) {
			my $outname = $outfield . $sd1 . '/' . $sd2 . '/' . $value;
			FlushOutToIndexFile ($outname, $fname, \%{$idlist{$cat}{$att}});
		    }   
		}
	    }
	}
    } elsif ($itype eq 'grammatical') {
        # do grammatical-specific indexing here, or combine with
        # above
    }
}

sub FlushOutToIndexFile {

    #use Compress::Zlib;
	
    my $outname = shift;
    my $fname = shift;
    my $hashref = shift;

    open (OUT, ">>$outname");
    print OUT $fname, "#";
    foreach my $s (keys % { $hashref }) {
	foreach my $p (@{$$hashref{$s}}) {
	    print OUT " $s-$p";
	}
    }
    print OUT "\n";
    close (OUT);

}

sub AddToAnnotationInOneProcess {

    use File::Basename;
    
    my $infile = shift;
    my $outfield = shift;
    my $itype = shift;
    my $pLexicon = shift;
    
    $outfield .= (SY_ANNOTATION_TYPE)->{$itype};
    
    if ($itype eq 'semantic') {
	
	# do semantic-specific annotation here
	
	(my $outfile, my $dummy1, my $dummy2) = fileparse($infile);
	open (OUT, ">$outfield$outfile");
	my @lines = GetLines($infile, 0);
	my $totallines = @lines;
	for (my $i = 0; $i < $totallines; $i++) {
	    AnnotateAndPrintLine (\*OUT, $i + 1, $lines[$i], $pLexicon);
	}  
	close (OUT);
    }
}

sub AnnotateAndPrintLine {
    
    local *OUT = shift;    
    my $sentenceid = shift;
    my $line = shift;
    my $pLexicon = shift;
    
    my $allexceptions = join (" ", @{(SY_MARKUP_EXCEPTIONS)}) . " ";
    my $ssl = (GE_DELIMITERS)->{start_sentence_left};
    my $ssr = (GE_DELIMITERS)->{start_sentence_right};
    my $boa = (GE_DELIMITERS)->{start_annotation};
    my $eoa = (GE_DELIMITERS)->{end_annotation};
    print OUT $ssl, $sentenceid, $ssr, "\n";
    
    my $dels = (GE_DELIMITERS)->{word};
    my @words = split /([$dels])/, $line; 
    # Eg. $line = "Growth hormone-releasing hormones are found."
    # @words = {Growth, ,hormone,-,releasing, ,hormones, ,are, ,found.}
    
    for (my $startindex = 0; $startindex < @words; $startindex += 2) {
	my $term = $words[$startindex];
	
	# Set the length of the longest string to be matched
	my $limit = @words;
	if ($limit > $startindex + 2*SY_MAX_NGRAM_SIZE) { # 2 because we have the delimiters in @words
	    $limit = $startindex + 2*SY_MAX_NGRAM_SIZE;
	}
	
	for (my $i = $startindex + 1; $i < $limit + 1; $i += 2) {
	    if ( keys % { $$pLexicon{$term} } ) {
		my @categories = ();
		foreach my $aux (keys % { $$pLexicon{$term} }) {
		    if ($allexceptions !~ /$aux /) {
			push @categories, $aux;
		    }
		}
		my $term1 = $term;
		
		print OUT "$boa\n";
		print OUT $term1, "\n";
		print OUT $startindex/2 + 1, "\n";
		foreach my $cat (@categories) {
		    print OUT $cat, " ";
		    print OUT "@{$$pLexicon{$term}{$cat}}", "\n";
		}
		print OUT "$eoa\n";
	    } elsif (HasPreprocessingTags($term, @{(SY_PREPROCESSING_TAGS)})) {
		my %auxlist = ProcessPreprocessingTags($term,  @{(SY_PREPROCESSING_TAGS)});
		foreach my $cat (keys % auxlist) {
		    my $term1 = $auxlist{$cat};
		    my $term2 = $term1;
		    
		    # remove occasional, additional SY_PREPROCESSING_TAGS that occur because
		    # of incomplete preprocessing or double phrases.
		    foreach my $item (@{(SY_PREPROCESSING_TAGS)}) {
			$term1 =~ s/\<$item\S*?\>//g;
			$term1 =~ s/\<\/$item\>//g;
		    }

		    print OUT "$boa\n";
		    print OUT $term1, "\n";
		    print OUT $startindex/2 + 1, "\n";		
		    print OUT $cat, " ";
		    if (defined($$pLexicon{$term2}{$cat})) {
			print OUT "@{$$pLexicon{$term2}{$cat}}";
		    } else {
			delete $$pLexicon{$term2}{$cat};
		    }
		    print OUT "\n";
		}
		my $tagfreeterm = $term; # check whether the preprocessing-tag-free
		                         # term has entries in other categories; if
		                         # so, put them out.
		foreach my $item (@{(SY_PREPROCESSING_TAGS)}) {
		    $tagfreeterm =~ s/\<$item\S*?\>//g;
		    $tagfreeterm =~ s/\<\/$item\>//g;
		}
		if (keys%{$$pLexicon{$tagfreeterm}}) {
		    my $cheatsheet = join (" ", (keys % auxlist));
		    foreach my $cat (keys%{$$pLexicon{$tagfreeterm}}) {
			if ($cheatsheet !~ /$cat/) {
			    print OUT $cat. " ";
			    print OUT "@{$$pLexicon{$tagfreeterm}{$cat}}", "\n";
			}
		    }
		} else {
		    delete $$pLexicon{$tagfreeterm};
		}
		print OUT "$eoa\n";
		delete $$pLexicon{$term};
	    } else {
		delete $$pLexicon{$term};
	    }
	    $term .= $words[$i] . $words[$i+1];
	}
    }
    my $eos = (GE_DELIMITERS)->{end_sentence};  
    print OUT "$eos\n";
}

sub AnnotateAndPrintLineGz { # not used, keep for a short while
    
    my $gz = shift;    
    my $sentenceid = shift;
    my $line = shift;
    my $pLexicon = shift;
    
    my $allexceptions = join (" ", @{(SY_MARKUP_EXCEPTIONS)}) . " ";
    my $ssl = (GE_DELIMITERS)->{start_sentence_left};
    my $ssr = (GE_DELIMITERS)->{start_sentence_right};
    my $boa = (GE_DELIMITERS)->{start_annotation};
    my $eoa = (GE_DELIMITERS)->{end_annotation};
    $gz->gzwrite("$ssl$sentenceid$ssr\n");
    
    my $dels = (GE_DELIMITERS)->{word};
    my @words = split /([$dels])/, $line; 
    # Eg. $line = "Growth hormone-releasing hormones are found."
    # @words = {Growth, ,hormone,-,releasing, ,hormones, ,are, ,found.}
    
    for (my $startindex = 0; $startindex < @words; $startindex += 2) {
	my $term = $words[$startindex];
	
	# Set the length of the longest string to be matched
	my $limit = @words;
	if ($limit > $startindex + 2*SY_MAX_NGRAM_SIZE) { # 2 because we have the delimiters in @words
	    $limit = $startindex + 2*SY_MAX_NGRAM_SIZE;
	}
	
	for (my $i = $startindex + 1; $i < $limit + 1; $i += 2) {
	    if ( keys % { $$pLexicon{$term} } ) {
		my @categories = ();
		foreach my $aux (keys % { $$pLexicon{$term} }) {
		    if ($allexceptions !~ /$aux /) {
			push @categories, $aux;
		    }
		}
		my $term1 = $term;
		
		$gz->gzwrite("$boa\n");
		$gz->gzwrite("$term1\n");
		$gz->gzwrite($startindex/2 + 1 . "\n");
		foreach my $cat (@categories) {
		    $gz->gzwrite($cat . " ");
		    $gz->gzwrite("@{$$pLexicon{$term}{$cat}}" . "\n");
		}
		$gz->gzwrite("$eoa\n");
	    } elsif (HasPreprocessingTags($term, @{(SY_PREPROCESSING_TAGS)})) {
		my %auxlist = ProcessPreprocessingTags($term,  @{(SY_PREPROCESSING_TAGS)});
		foreach my $cat (keys % auxlist) {
		    my $term1 = $auxlist{$cat};
		    my $term2 = $term1;
		    
		    # remove occasional, additional SY_PREPROCESSING_TAGS that occur because
		    # of incomplete preprocessing or double phrases.
		    foreach my $item (@{(SY_PREPROCESSING_TAGS)}) {
			$term1 =~ s/\<$item\S*?\>//g;
			$term1 =~ s/\<\/$item\>//g;
		    }

		    $gz->gzwrite("$boa\n");
		    $gz->gzwrite("$term1\n");
		    $gz->gzwrite($startindex/2 + 1 . "\n");
		    $gz->gzwrite($cat . " ");
		    if (defined($$pLexicon{$term2}{$cat})) {
			$gz->gzwrite("@{$$pLexicon{$term2}{$cat}}");
		    } else {
			delete $$pLexicon{$term2}{$cat};
		    }
		    $gz->gzwrite("\n");
		}
		my $tagfreeterm = $term; # check whether the preprocessing-tag-free
		                         # term has entries in other categories; if
		                         # so, put them out.
		foreach my $item (@{(SY_PREPROCESSING_TAGS)}) {
		    $tagfreeterm =~ s/\<$item\S*?\>//g;
		    $tagfreeterm =~ s/\<\/$item\>//g;
		}
		if (keys%{$$pLexicon{$tagfreeterm}}) {
		    my $cheatsheet = join (" ", (keys % auxlist));
		    foreach my $cat (keys%{$$pLexicon{$tagfreeterm}}) {
			if ($cheatsheet !~ /$cat/) {
			    $gz->gzwrite($cat . " ");
			    $gz->gzwrite("@{$$pLexicon{$tagfreeterm}{$cat}}" . "\n");
			}
		    }
		} else {
		    delete $$pLexicon{$tagfreeterm};
		}
		$gz->gzwrite("$eoa\n");
		delete $$pLexicon{$term};
	    } else {
		delete $$pLexicon{$term};
	    }
	    $term .= $words[$i] . $words[$i+1];
	}
    }
    my $eos = (GE_DELIMITERS)->{end_sentence};  
    $gz->gzwrite("$eos\n");
}

sub RemoveFromIndex {
    
    use File::Basename;
    
    my $infile = shift;
    my $outfield = shift;
    my $itype = shift;
    $outfield .= (SY_INDEX_TYPE)->{$itype};
    (my $fname, my $fdir, my $fsuf) = fileparse($infile);
    
    if ($itype eq 'keyword') {
	my %idlist = KeywordParse($infile);
	foreach my $key (keys % idlist) {
	    my $sd1 = substr($key, 0, 1);
	    my $outname;
	    if (length($key) > 1) {
		my $sd2 = substr($key, 1, 1);
		$outname = $outfield . $sd1 . '/' . $sd2 . '/' . $key;
	    } else {
		$outname = $outfield . $sd1 . '/LITERAL';
	    }
	    ZapFromIndexFile ($outname, $fname);
	}
	
    } elsif ($itype eq 'semantic') {
	my %idlist = AnnotationParse($infile);
	my $pcat = (GE_DELIMITERS)->{parent_category};
	foreach my $cat (keys % idlist) {
	    foreach my $att (keys %{$idlist{$cat}}) {
		if ($att =~ /$pcat/) {
		    my $outname = $outfield . (SY_INDEX_SUBTYPE)->{categories} . $cat;
		    ZapFromIndexFile ($outname, $fname);
		} else {
		    my $sd1 = (SY_INDEX_SUBTYPE)->{attributes} . $cat;
		    (my $sd2) = $att =~ /(.+?)=/;
		    (my $aux) = $att =~ /=\'(.+?)\'/;
		    my @values = split (/\|/, $aux);
		    foreach my $value (@values) 
		    {
			my $outname = $outfield . $sd1 . '/' . $sd2 . '/' . $value;
			ZapFromIndexFile ($outname, $fname);
		    }
		} 
	    }
    	}
    } elsif ($itype eq 'grammatical') {
	# do grammatical-specific removing here, or combine with
	# above
    }
    
}

sub ZapFromIndexFile {
    
    my $outname = shift;
    my $fname = shift;
    
    my @lines = GetLines ($outname);
    open (OUT, ">$outname");
    foreach my $line (@lines) {
	if ($line !~ /$fname/) {
	    print OUT $line, "\n";
	}
    }
    close (OUT);
}

sub RemoveFromAnnotation {
    
    use File::Basename;
    
    my $infile = shift;
    my $outfield = shift;
    my $itype = shift;
    $outfield .= (SY_ANNOTATION_TYPE)->{$itype};
    
    (my $outfile, my $dummy1, my $dummy2) = fileparse($infile);
    unlink("$outfield$outfile");
    
}

sub AddToSupplementals {}

sub RemoveFromSupplementals {}

sub KeywordParse {

    use File::Basename;

    my $infile = shift;
    my %idlist = ();
    
    my $stpwrdfname = SY_ROOT . (SY_SUBROOTS)->{etc} . 'stopwords';
    my %stopwords = GetStopWords($stpwrdfname);

    my @lines = GetLines($infile);
    for (my $i = 0; $i < @lines; $i++) {
        my $lineid = $i + 1;
        my @items = GetItemList($lines[$i]);
	for (my $j = 0; $j < @items; $j++) {
	    $items[$j] =~ s/\s//g;
	    $items[$j] =~ s/^-//g;
	    $items[$j] =~ s/-$//g;
	    if ((length($items[$j]) > 0) && 
		(substr($items[$j], 0, 1) =~ /\w/) && 
		(!$stopwords{"\L$items[$j]\E"})) {
		push @{$idlist{$items[$j]}{$lineid}}, $j + 1;
	    }
	}
    }
    
    return %idlist;
}

sub AnnotationParse {
    
    my $infile = shift;
    my %list = ();
    
    my $inline = join ("\n", GetLines($infile)) . "\n";
    my $eos = (GE_DELIMITERS)->{end_sentence};	
    my @sentences = split (/$eos\n/, $inline);
    my $pcat = (GE_DELIMITERS)->{parent_category};
    my $ssl = (GE_DELIMITERS)->{start_sentence_left};
    my $ssr = (GE_DELIMITERS)->{start_sentence_right};
    my $boa = (GE_DELIMITERS)->{start_annotation};
    my $eoa = (GE_DELIMITERS)->{end_annotation};
    foreach my $sentence (@sentences) {
	(my $sid) = $sentence =~ /$ssl(\d+)$ssr/;
	my @auxlines =  split (/$eoa\n/, $sentence);
	my %annotations = ();
	foreach my $aux (@auxlines) {
	    $aux =~ s/\A.*$boa\n//s;
	    my @lines = split (/\n/, $aux);
	    my $posid = $lines[1];
	    chomp ($posid);
	    for (my $i = 2; $i < @lines; $i++) {
		chomp($lines[$i]);
		push @{$annotations{$posid}}, $lines[$i];
	    }
	}
	foreach my $pos (keys % annotations) {
	    foreach my $annotation (@{$annotations{$pos}}) {
		(my $category, my @attributes) = split (/ /, $annotation);
		push @{$list{$category}{$pcat}{$sid}}, $pos;
		foreach my $attribute (@attributes) {
		    push @{$list{$category}{$attribute}{$sid}}, $pos;
		}
	    }
	}
    }
    return %list;
    
}

sub GetItemList {
    
    my $line = shift;
    my $ked = (GE_DELIMITERS)->{keyword_entry};
    my @itemlist = split (/[$ked]+/, $line);
    my @cleanedlist = ();
    foreach my $item (@itemlist) {
        if ($item =~ /.+/) { push @cleanedlist, $item }
    }
    return @cleanedlist;
}

sub Tokenizer {

    my @incoming = @_;

    my $line = join ("\n", @incoming) . "\n";

    # joins words hyphenated by the end of line
    $line =~ s/([a-z]+)- *\n+([a-z]+)/$1$2/g;

    # replace multiple white spaces with just " ";
    $line =~ s/\s+/ /g;

    # first assume that all ? ! . are ends of sentences
    # disqualify following incidents by using an underscore

    # disqualify period after sing. capit. letters ( M. Young -> M Young)
    $line =~ s/(\b[A-Z])\. /$1_DSQPRD_ /g;

    # disqualify the "ca. <NUMBER>" notation!!!
    $line =~ s/( [cC]a)\.( \d+)/$1_DSQPRD_$2/g;

    # disqualify common abbreviations ... 
    $line =~ s/([eE])\.[gG]\./$1_DSQPRD_$2_DSQPRD_/g;
    $line =~ s/([iI])\.[eE]\./$1_DSQPRD_$2_DSQPRD_/g;       
    $line =~ s/([Aa]l)\./$1_DSQPRD_/g;
    $line =~ s/([Ee]tc)\./$1_DSQPRD_/g;  
    $line =~ s/([Ee]x)\./$1_DSQPRD_/g;
    $line =~ s/([Vv]s)\./$1\.|_/g;
    $line =~ s/([Nn]o)\./$1_DSQPRD_/g;
    $line =~ s/([Vv]ol)\./$1_DSQPRD_/g;
    $line =~ s/([Ff]igs?)\./$1_DSQPRD_/g;
    $line =~ s/([Ss]t)\./$1_DSQPRD_/g;
    $line =~ s/([Cc]o)\./$1_DSQPRD_/g;
    $line =~ s/Dr\./Dr_DSQPRD_/g;
    $line =~ s/Ph\.D\./Ph_DSQPRD_D_DSQPRD_/g;
    $line =~ s/Prof\./Prof_DSQPRD_/g;

    #disqualify numbers
    $line =~ s/(\d+ ?)\.( ?\d+)/$1_DSQPRD_$2/g;

    # rules for journal titles
    # disqualifies abbreviated journal title names!
    # disabled for now, too many false positives
    # $line =~ s/([A-Z]\w+ \.)( )([A-Z]\w* \.)?( )?([A-Z]\w* \.)?( )?([A-Z]\w* \.)?( )?([A-Z]\w* \.)?/$1\_$2$3\_$4$5\_$6$7\_$8\_$9/g;           
    
    # general rule...
    # disqualify any period followed by a space then a small letter
    $line =~ s/\.( [a-z])/_DSQPRD_$1/g;
    
    # special instances not caught by general rules...
    # EXCEPTION; qualify those sentences that begin 
    # with a small letter ie begin with a gene name!!!
    $line =~ s/_DSQPRD_( [a-z]{3,4}-\d+)/\.$1/g;

    # EXCEPTION; qualify those sentences that end with 
    # a capitalized abreviation, eg RNA!!!
    $line =~ s/ (\w+[A-Z]{2})_DSQPRD_/ $1\./g;

    # need to preserve pre-processing tags
    my $auxno = 0;
    my %memlist = ();
    foreach my $item (@{(SY_PREPROCESSING_TAGS)}) {
	my @aux1 = $line =~ /(\<$item\S*?\>)/g;
	my @aux2 = $line =~ /(\<\/$item\>)/g;
	foreach my $a (@aux1,@aux2) {
	    $memlist{$a} = $auxno++;
	}
    }
    foreach my $a (keys % memlist) {
	my $n = $memlist{$a};
	$line =~ s/$a/\_SYP$n\_/g;
    }

    # rules for replacing perl metacharacters 
    # and other characters worth keeping
    # with literal descriptions in text ...
    $line = ReplaceSpecChar($line);
    $line = ReplaceDashAndWhitespace($line);

    # need to get rid of any other non-literal character
    $line =~ s/\W//g;

    # need to replace back dash;
    $line = InverseReplaceDashAndWhitespace($line);

    # reverse preserving preprocessing tags
    foreach my $a (keys % memlist) {
	my $n = $memlist{$a};
	$line =~ s/\_SYP$n\_/$a/g;
    }
    
    my $qm = (GE_SPECIALCHARS)->{'\?'};
    my $em = (GE_SPECIALCHARS)->{'\!'};
    my $pd = (GE_SPECIALCHARS)->{'\.'};
    # reintroduce newline for qualified ends of sentence
    $line =~ s/($qm )/$1\n/g;
    $line =~ s/($em )/$1\n/g;
    $line =~ s/($pd )/$1\n/g;

    # reverse _DSQPRD_;
    $line =~ s/_DSQPRD_/$pd/g;

    # places newline after section titles! 
    $line =~ s/\b(ABSTRACT|RESEARCH COMMUNICATION|INTRODUCTION|(RESULTS? )(AND )?(DISCUSSIONS?)?|REFERENCES?)\b/$1\n/g;  
    $line =~ s/\b(Abstract|Research Communication|Introduction|(Results? )([aA]nd )?(Discussions?)?|References?)\b/$1\n/g;  

    # Materials and methods disabled for now, too many false positives
    # $line =~ s/\b((MATERIALS? )?(AND )?(METHODS?)?)\b/$1\n/g;  
    # $line =~ s/\b((Materials? )?([aA]nd )?(Methods?))\b/$1\n/g;  
    
#    # replace multiple white spaces with just " ";
#    $line =~ s/ +/ /g;

    return $line;

}

sub Tokenizer_Old {
    
    my @incoming = @_;
    my $line = join ("\n", @incoming) . "\n";

    # few things to begin with..
    
    # joins words hyphenated by the end of line
    $line =~ s/([a-z]+)- *\n+([a-z]+)/$1$2/g;
    # gets rid of hyphen in word, hypen, space, eg homo- and heterodimers
    $line =~ s/(\w+)- +/$1 /g;
    
    # deal with a period
    
    # gets rid of p.  after sing. capit. letters ( M. Young -> M Young)
    $line =~ s/(\b[A-Z])\./$1/g;
    # protect the "ca. <NUMBER>" notation!!!
    $line =~ s/( ca)\.( \d+)/$1$2/g;
    # gets rid of alot of extraneous periods within sentences ... 
    $line =~ s/e\.g\./eg/g;
    $line =~ s/i\.e\./ie/g;       
    $line =~ s/([Aa]l)\./$1/g;
    $line =~ s/([Ee]tc)\./$1/g;  
    $line =~ s/([Ee]x)\./$1/g;
    $line =~ s/([Vv]s)\./$1/g;
    $line =~ s/([Nn]o)\./$1/g;
    $line =~ s/([Vv]ol)\./$1/g;
    $line =~ s/([Ff]igs?)\./$1/g;
    $line =~ s/([Ss]t)\./$1/g;
    $line =~ s/([Cc]o)\./$1/g;
    $line =~ s/([Dd]r)\./$1/g;
    
    # now get rid of any newline characters, but protect already 
    # recognized end of sentence

    $line =~ s/ \. \n/_PERIOD_EOS__/g;
    $line =~ s/ \? \n/_QMARK_EOS__/g;
    $line =~ s/ \! \n/_EMARK_EOS__/g;
    
    # replaces new line character with a space
    $line =~ s/\n/ /g;
    
    # "protect" instances of periods that do not 
    # mark the end of a sentence by substituting 
    # an underscore for the following space i.e. 
    # ". " becomes "._"
    
    # general rule...
    # protect any period followed by a space then a small letter
    $line =~ s/\. ([a-z])/\._$1/g;
    
    # special instances not caught by general rules...
    # EXCEPTION; unprotect those sentences that begin 
    # with a small letter ie begin with a gene name!!!
    $line =~ s/\._([a-z]{3,4}-\d+)/\. $1/g;
    # EXCEPTION; unprotect those sentences that end with 
    # a capitalized abreviation, eg RNA!!!
    $line =~ s/ (\w+[A-Z]{2})\._/ $1\. /g;
    
    #rules for journal titles
    # protects abbreviated journal title names!
    $line =~ s/([A-Z]\w+\.) ([A-Z]\w*\.) ?([A-Z]\w*\.)? ?([A-Z]\w*\.)? ?([A-Z]\w*\.)?/$1_$2_$3_$4_$5/g;           
    
    # reintroduce newline characters at ends
    # of sentences only where there
    # is a period followed by a space.
    $line =~ s/(\S\.|\S\?|\S\!) /$1\n/g;
    # modified by HMM previous line to match more cases 
    # for 'reintroduces newlines'
    
    # reverse recognized EOSes
    $line =~ s/_PERIOD_EOS__/ \. \n/g;
    $line =~ s/_QMARK_EOS__/ \? \n/g;
    $line =~ s/_EMARK_EOS__/ \! \n/g;
    

# commented out because too many false positives    
#    # places newline after section titles! 
#    $line =~ s/\b(ABSTRACT|RESEARCH COMMUNICATION|INTRODUCTION|MATERIALS AND METHODS|RESULTS|DISCUSSION|RESULTS AND DISCUSSION|REFERENCES)\b/$1\n/gi;  
    
    # reintroduce spaces following periods that 
    # do not mark the end of a sentence 
    # unprotects any period followed by a space and an small letter
    $line =~ s/\._([a-z])/\. $1/g;
    # unprotects any journal article names
    $line =~ s/([A-Z]\w+\.)_([A-Z]\w*\.)?_?([A-Z]\w*\.)?_?([A-Z]\w*\.)?_?([A-Z]\w*\.)?/$1 $2 $3 $4 $5/g;
    
    # rules for replacing perl metacharacters 
    # and other characters worth keeping
    # with literal descriptions in text ...
    
    # turns " into DQ
    $line =~ s/\"/_DQ__/g;
    # turns < into LT    
    $line =~ s/\</_LT__/g;
    # turns > into GT
    $line =~ s/\>/_GT__/g; 
    # turns + into EQ
    $line =~ s/\=/_EQ__/g;
    # turns & into AND
    $line =~ s/\&/_AND__/g;
    # turns @ into AT
    $line =~ s/\@/_AT__/g; 
    # turns / into SLASH
    $line =~ s/\//_SLASH__/g;
    # turns $ into DOLLAR
    $line =~ s/\$/_DOLLAR__/g;
    # turns % into PERCENT
    $line =~ s/\%/_PERCENT__/g;
    # turns ^ into CARET
    $line =~ s/\^/_CARET__/g;
    # turns * into STAR
    $line =~ s/\*/_STAR__/g;
    # turns + into PLUS
    $line =~ s/\+/_PLUS__/g;
    # turns | into VERTICAL
    $line =~ s/\|/_VERTICAL__/g;
    # turns \ into BACKSLASH
    $line =~ s/\\/_BACKSLASH__/g;

    # including turning all punctuation 
    # into literals .....
    $line =~ s/\./_PERIOD__/g;
    $line =~ s/\?/_QMARK__/g;
    $line =~ s/\!/_EMARK__/g;
    $line =~ s/,/_COMMA__/g;
    $line =~ s/;/_SEMICOLON__/g;
    $line =~ s/:/_COLON__/g;
    $line =~ s/\[/_OPENSB__/g;
    $line =~ s/\]/_CLOSESB__/g;
    $line =~ s/\(/_OPENRB__/g;
    $line =~ s/\)/_CLOSERB__/g;
    $line =~ s/\{/_OPENCB__/g;
    $line =~ s/\}/_CLOSECB__/g;
    $line =~ s/\-/_HYPHEN__/g;
    $line =~ s/\n/_NLC__/g;
    $line =~ s/ /_SPACE__/g;
    
    # now get fid of any non-literal characters...
    
    $line =~ s/\W//g;
    
    # now replace all back ...
    
    $line =~ s/_DQ__/\"/g;
    $line =~ s/_LT__/\</g;	
    $line =~ s/_GT__/\>/g;
    $line =~ s/_EQ__/\=/g;
    $line =~ s/_AND__/\&/g;
    $line =~ s/_AT__/\@/g;
    $line =~ s/_SLASH__/\//g;
    $line =~ s/_DOLLAR__/\$/g;
    $line =~ s/_PERCENT__/\%/g;
    $line =~ s/_CARET__/\^/g;
    $line =~ s/_STAR__/\*/g;
    $line =~ s/_PLUS__/\+/g;
    $line =~ s/_VERTICAL__/\|/g;
    $line =~ s/_BACKSLASH__/\\/g;
    $line =~ s/_PERIOD__/\./g;
    $line =~ s/_QMARK__/\?/g;
    $line =~ s/_EMARK__/\!/g;
    $line =~ s/_COMMA__/,/g;
    $line =~ s/_SEMICOLON__/;/g;
    $line =~ s/_COLON__/:/g;
    $line =~ s/_OPENSB__/\[/g;
    $line =~ s/_CLOSESB__/\]/g;
    $line =~ s/_OPENRB__/\(/g;
    $line =~ s/_CLOSERB__/\)/g;
    $line =~ s/_OPENCB__/\{/g;
    $line =~ s/_CLOSECB__/\}/g;
    $line =~ s/_HYPHEN__/\-/g;
    $line =~ s/_NLC__/\n/g;
    $line =~ s/_SPACE__/ /g;
    
    # rules for tokenizing punctuation marks in text
    # places space around ();:,.[]{}
    $line =~ s/([\)\:\;\,\.\(\[\{\}\]])/ $1 /g;
    
    # finally, clean up any extra spaces####
    # gets rid of tabs
    $line =~ s/\t/ /g;
    # gets rid of extra space              
    $line =~ s/ +/ /g;
    # gets rid of space after newline   
    $line =~ s/\n\s+/\n/g;   
    
    return $line;
    
}

sub SpecialReplacements {
    
    my @lines = @_;

    for (my $i = 0; $i < @lines; $i++) {

	# rules for converting abreviations to whole words....

	$lines[$i] =~ s/([\w]+)\'[Ll][Ll]/$1 will/g;          # eg i'll turns into i will
	$lines[$i] =~ s/([\w]+)\'[Rr][Ee]/$1 are/g;           # eg you're turns into you are
	$lines[$i] =~ s/([\w]+)\'[Vv][Ee]/$1 have/g;          # eg i've turns into i have
	$lines[$i] =~ s/ ([Ww])on\'t/ $1ill not/g;            # eg won't turns into will not
	$lines[$i] =~ s/ ([Dd])on\'t/ $1oes not/g;            # eg don't turns into does not
	$lines[$i] =~ s/ ([Hh])aven\'t/ $1ave not/g;          # eg haven't turns into have not
	$lines[$i] =~ s/ ([Cc])an\'t/ $1an not/g;             # eg can't turns into can not
	$lines[$i] =~ s/ ([Cc])annot/ $1an not/g;             # eg cannot turns into can not
	$lines[$i] =~ s/ ([Ss])houldn\'t/ $1hould not/g;      # eg shouldn't turns into should not
	$lines[$i] =~ s/ ([Cc])ouldn\'t/ $1ould not/g;        # eg couldn't turns into could not
	$lines[$i] =~ s/ ([Ww])ouldn\'t/ $1ould not/g;        # eg wouldn't turns into would not
	$lines[$i] =~ s/ ([Mm])ayn\'t/ $1ay not/g;            # eg mayn't turns into may not
	$lines[$i] =~ s/ ([Mm])ightn\'t/ $1ight not/g;        # eg mightn't turns into might not
	$lines[$i] =~ s/ [Tt]is/ it is/g;                     # eg tis turns into it is
	$lines[$i] =~ s/ [Tt]was/ it was/g;                   # eg twas turns into it was
	$lines[$i] =~ s/ ([iI]t)\'[sS]/ $1 is/g;                # eg it's turns into it is
	$lines[$i] =~ s/ ([iI]t?)\'[dD]/ $1 would/g;             # eg I/it'd turns into I/it would
	$lines[$i] =~ s/ ([iI])\'[mM]/ $1 am/g;                # eg i'm turns into i am

    }
    return @lines;

}

sub SpecialReplacements_Old {
    
    my $line = shift;
    
    # rules for converting abreviations to whole words....
    
    $line =~ s/([\w]+)\'[Ll][Ll]/$1 will/g;          # eg i'll turns into i will
    $line =~ s/([\w]+)\'[Rr][Ee]/$1 are/g;           # eg you're turns into you are
    $line =~ s/([\w]+)\'[Vv][Ee]/$1 have/g;          # eg i've turns into i have
    $line =~ s/ ([Ww])on\'t/ $1ill not/g;            # eg won't turns into will not
    $line =~ s/ ([Dd])on\'t/ $1oes not/g;            # eg don't turns into does not
    $line =~ s/ ([Hh])aven\'t/ $1ave not/g;          # eg haven't turns into have not
    $line =~ s/ ([Cc])an\'t/ $1an not/g;             # eg can't turns into can not
    $line =~ s/ ([Cc])annot/ $1an not/g;             # eg cannot turns into can not
    $line =~ s/ ([Ss])houldn\'t/ $1hould not/g;      # eg shouldn't turns into should not
    $line =~ s/ ([Cc])ouldn\'t/ $1ould not/g;        # eg couldn't turns into could not
    $line =~ s/ ([Ww])ouldn\'t/ $1ould not/g;        # eg wouldn't turns into would not
    $line =~ s/ ([Mm])ayn\'t/ $1ay not/g;            # eg mayn't turns into may not
    $line =~ s/ ([Mm])ightn\'t/ $1ight not/g;        # eg mightn't turns into might not
    $line =~ s/ [Tt]is/ it is/g;                     # eg tis turns into it is
    $line =~ s/ [Tt]was/ it was/g;                   # eg twas turns into it was
    $line =~ s/ (\w+)\'[sS]/ $1 is/g;                # eg it's turns into it is
    $line =~ s/ (\w+)\'[dD]/ $1 would/g;             # eg it'd turns into it would
    $line =~ s/ (\w+)\'[mM]/ $1 am/g;                # eg i'm turns into i am
    
    return $line;
    
}

sub RemovePreprocessingTags {

    my $file = shift;
    
    my $accumulated = "";
    undef $/;
    open (IN, "<$file") || return;
    $accumulated = <IN>;
    close (IN);
    $/ = "\n";
    foreach my $item (@{(SY_PREPROCESSING_TAGS)}) {
	$accumulated =~ s/\<$item\S*?\>//g;
	$accumulated =~ s/\<\/$item\>//g;
    }
    open (OUT, ">$file");
    print OUT $accumulated;
    close (OUT);
}

sub HasPreprocessingTags {
    
    my $term = shift;
    my @tags = @_;
    foreach my $tag (@tags) {
	if ($term =~ /^\<$tag\S*?\>\S+?\<\/$tag\>$/) {
	    return 1;
	}
    }
    return 0;
}

sub ProcessPreprocessingTags {
    
    my $term = shift;
    my @tags = @_;
    my @aux = ();
    foreach my $tag (@tags) {
	my @aux2 = $term =~ /^\<$tag\_(\S*?)\>(\S+?)\<\/$tag\>$/;
	@aux = (@aux, @aux2);
    }
    my %retaux = ();
    while (@aux) {
	my $attstring = shift(@aux);
	if ($attstring =~ /\=yes/) {
	    (my $cat) = $attstring =~ /(\S+?)\=yes/;
	    $retaux{$cat} = shift(@aux);
	}
    }
    return %retaux;
}

1;
