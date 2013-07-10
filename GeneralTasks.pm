package GeneralTasks;
# contains sub-routines generic to all MODs

use strict;
use GeneralGlobals;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(getXmlFormat 
                 get_web_page mailer 
                 getDoi 
                 getGeneticsId 
                 getArticleTitle 
                 getAuthors 
                 convertDosFileToUnixFile 
                 getNewFiles 
                 dontLinkLine
                 removeLinksInAcknowledgments
                 replace_hidden_entities
                 highlight_text
                 create_linked_xml_file
                 get_hidden_entity
                ); 


sub getXmlFormat {
    my $file = shift;

    my $format = "";
    open(IN, "<$file") or die("died: could not open $file for reading.\n");
    while (my $line = <IN>) {
        chomp($line);
        if ($line =~ m#<\?xml-stylesheet href="document\.css" type="text/css" \?>#) {
            $format = GeneralGlobals::FLAT_XML_ID;
            last;
        } elsif ($line =~ m#<!DOCTYPE article PUBLIC "-//NLM//DTD Journal Publishing DTD#) { 
            $format = GeneralGlobals::NLM_XML_ID;
            last;
        }
    }
    close(IN);

    if ($format eq "") {
        die("died: could not determine XML format for $file.\n");
    }

    return $format;
}

####################################################################
sub getDoi {
    my $xml = shift;
    my $format = shift;

    my $ret = "";

    if ($format eq FLAT_XML_ID) {
        $ret = getDoiFlatXml($xml);
    } elsif ($format eq NLM_XML_ID) {
        $ret = getDoiNlmXml($xml);
    }

    return $ret;
}

sub getDoiFlatXml {
    my $xml = shift;
    $xml =~ /\<doi\>(.+?)\<\/doi\>/;
    return $1;
}

sub getDoiNlmXml {
    my $xml = shift;
    $xml =~ /<article-id pub-id-type="doi">(.+?)<\/article-id>/;
    return $1;
}

####################################################################
sub getGeneticsId {
    my $xml = shift;
    my $format = shift;

    my $ret = "";

    if ($format eq FLAT_XML_ID) {
        $ret = getGeneticsIdFlatXml($xml);
    } elsif ($format eq NLM_XML_ID) {
        $ret = getGeneticsIdNlmXml($xml);
    }

    return $ret;
}

sub getGeneticsIdFlatXml {
    my $xml = shift;
    $xml =~ /\<doi\>(.+?)\<\/doi\>/;
    my $doi = $1;
    $doi =~ /\.(\d+)$/;
    return $1;
}

sub getGeneticsIdNlmXml {
    my $linked_xml = shift;
    $linked_xml =~ /<article-id pub-id-type="publisher-id">(.+?)<\/article-id>/;
    return $1;
}

####################################################################
sub getArticleTitle {
    my $xml = shift;
    my $format = shift;

    my $ret = "";

    if ($format eq FLAT_XML_ID) {
        $ret = getArticleTitleFlatXml($xml);
    } elsif ($format eq NLM_XML_ID) {
        $ret = getArticleTitleNlmXml($xml);
    }

    return $ret;
}

sub getArticleTitleFlatXml {
    my $xml = shift;

    while ($xml =~ /\<Article_Title\>(.+?)\<\/Article_Title\>/g) {
        my $match = $1;
        next if ($match eq "Note"); # don't know why some articles have this! 
        return $1;
    }

    die("died: article does not have a title in Article_Title tags!\n"); 
}

sub getArticleTitleNlmXml {
    my $xml = shift;
    $xml =~ /<article-title>(.+?)<\/article-title>/;
    my $title = $1;
    $title =~ s/<italic>/<I>/g;
    $title =~ s/<\/italic>/<\/I>/g;
    return $title;
}

####################################################################
sub getAuthors {
    my $xml = shift;
    my $format = shift;

    my $ret = "";

    if ($format eq FLAT_XML_ID) {
        $ret = getAuthorsFlatXml($xml);
    } elsif ($format eq NLM_XML_ID) {
        $ret = getAuthorsNlmXml($xml);
    }

    return $ret;
}

sub getAuthorsFlatXml {
    my $linked_xml = shift;
    $linked_xml =~ /\<Authors\>(.+?)\<\/Authors\>/;
    my $authors = $1;
    $authors =~ s/\<a href=.+?\"\>//g;
    $authors =~ s/\<\/a\>//g;
    $authors =~ s/\<SUP\>.+?\<\/SUP\>//g;

    return $authors;
}

sub getAuthorsNlmXml {
    my $linked_xml = shift;
    $linked_xml =~ /<contrib contrib-type="author"(.+)/;
    my $author_line = $1;
    my $authors = "";
    while ($author_line =~ /<surname>(.+?)<\/surname><given-names>(.+?)<\/given-names>/g) {
        $authors .= "$2 $1, ";
    }
    $authors =~ s/\, $//;
    return $authors;
}
####################################################################

sub get_web_page{
    my $u = shift;
    my $page = "";
    use LWP::UserAgent;
    
    my $ua = LWP::UserAgent->new(agent => '04formEntityTable.pl (GSA)',
                                 timeout => 15); # instantiates a new user agent
    # dev.textpresso.org does not understand the following param.
    # also wormbase.org does not seem to work any better with this. requests still time out.
    # $ua->default_header('Cache-Control' => 'max-age=0');

    my $request = HTTP::Request->new(GET => $u); # grabs url
    my $response = $ua->request($request);       # checks url, dies if not valid.
    
    if ($response->is_success) {
        $page = $response->content;    #splits by line
    } else {
        warn $response->status_line,"\n";
        $page = $response->status_line;
    }

    return $page;
}

sub mailer {                    # send non-attachment mail
    use Mail::Mailer;

    my ($sender, $receiver, $subject, $body) = @_;

    #print "Sending email to $receiver with subject \'$subject\'...\n";

    # add couple of words in the email, so that people know this is an automated email.
    $subject = "GSA auto-email: " . $subject;

    $body = "This is an automatic email sent to you by the GSA pipeline.\n\n" . $body;

    my $command = 'sendmail';
    my $mailer = Mail::Mailer->new($command) ;
    $mailer->open({ From    => $sender,
                    To      => $receiver,
                    Subject => $subject,
                 })
             or die "Can't open: $!\n";
    print $mailer $body;
    $mailer->close();
}

sub convertDosFileToUnixFile {
    my $txtFile = shift;
    my @args = ("dos2unix", "$txtFile");
    system(@args) == 0 or print "could not convert dos files to unix files. you may get ^M at the end of lines\n
    Manually convert the dos files to UNIX files using dos2unix and remove the conversion in the script";
}

sub getNewFiles {
    my $in = shift;
    my $outdir = shift;
    $outdir =~ s/\/$//; # just remove the last / from the dir name
    
    my @newfiles = ();

    if (-d $in) { # auto-run
        @newfiles = getNewFilesInDir($in, $outdir);

        if (scalar(@newfiles) == 0) {
            print "No new files to process.\n";
            exit(0);
        }
        print "There are ", scalar(@newfiles), " new files\n";
    } 
    else { #manual run
        push @newfiles, $in;
    }

    return @newfiles;
}

sub getNewFilesInDir {
    my $indir = shift;
    my $outdir = shift;

    my @newfiles = ();

    my @infiles  = <$indir/*>;
    my @outfiles = <$outdir/*>;

    my @inids = ();
    for my $infile (@infiles) {
        $infile =~ /(\d+)/;
        my $id = $1;
        push @inids, $id;
    }

    my @outids = ();
    for my $outfile (@outfiles) {
        $outfile =~ /(\d+)/;
        my $id = $1;
        push @outids, $id;
    }

    for my $inid (@inids) {
        my $already_proc = 0;
        
        for my $outid (@outids) {
            if ($outid == $inid) {
                $already_proc = 1;
                last;
            }
        }

        if ($already_proc == 0) {
            my @files = <$indir/*$inid*>; # should be only 1 file.
            warn "Multiple files in $indir with ID $inid\n" if (scalar(@files) > 1);
            
            for my $file (@files) { 
                push @newfiles, $file;
            }
        }
    }

    return @newfiles;
}

sub dontLinkLine {
    my $line   = shift;
    my $format = shift;

    if ($format eq "") {
        die("died: xmlformat is empty at GeneralTasks::dontLinkLine. has to be 'flat' or 'nlm xml'\n");
    }

    my $ret = 0;

    if ($format eq FLAT_XML_ID) {
        $ret = dontLinkLineFlatXml($line);
    } elsif ($format eq NLM_XML_ID) {
        $ret = dontLinkLineNlmXml($line);
    }

    return $ret;
}

sub dontLinkLineNlmXml {
    my $xml_line = shift;
    if ($xml_line =~ /^(<list-item>)?<p/) {
        return 0;
    }

    return 1;
}

sub dontLinkLineFlatXml {
    my $xml_line = shift;
    if ( ($xml_line =~ /\<Affiliations/) || 
         ($xml_line =~ /\<Correspondence/) || 
         ($xml_line =~ /\<Footnote/) || 
         ($xml_line =~ /\<Article_Title/) ||
         ($xml_line =~ /\<\S+_Runhead/) ||
         ($xml_line =~ /\<Bib_Reference/) ||
         ($xml_line =~ /\<entry.*rowsep=\"\d+\"/) || # this excludes table entries
         ($xml_line =~ /\<entry.*colsep=\"\d+\"/) || # this excludes table entries
         ($xml_line =~ /\<COMMENT/) ||
         ($xml_line =~ /\<H1/) ||
         ($xml_line =~ /\<H2/) ||
         ($xml_line =~ /\<H3/i) ||
         ($xml_line =~ /\<H4/) ||
         ($xml_line =~ /\<Table/) ||
         ($xml_line =~ /\<Figure/) ||
         ($xml_line =~ /\<Article_Subtitle/) ||
         ($xml_line =~ /\<Abbreviations/) ||
         ($xml_line =~ /\<Keywords/) ||
         ($xml_line =~ /\<Ack/) ||
         ($xml_line =~ /\<title\>/)                  # table titles - in the files analyzed so far
    ) {
        # print "dontLinkLineFlatXml: $xml_line\n";
        return 1;
    } else {
        return 0;
    }
}

sub removeLinksInAcknowledgments {
    my $xml = shift;

    $xml =~ m#<ack>\n<title>Acknowledgments</title>\n<p>(.+?)</p>\n</ack>#;
    my $ack_text_orig = $1;

    my $ack_text = $ack_text_orig;
    $ack_text =~ s#<a href="http://www\.wormbase\.org/.+?">(\S+?)</a>#$1#g;
    $ack_text =~ s#<a href="http://www\.yeastgenome\.org/.+?">(\S+?)</a>#$1#g;
    $ack_text =~ s#<a href="http://flybase\.org/.+?">(\S+?)</a>#$1#g;
    $ack_text =~ s#<a href="javascript:removeLinkAfterConfirm\('\S+?'\)"><sup><img src="/gsa/img/minus.png"/></sup></a>##g;


    $xml =~ s#\Q$ack_text_orig\E#$ack_text#;

    return $xml;
}

sub replace_hidden_entities {
    my $xml      = shift;
    my $orig_ref = shift;

    for my $hidden_entity (reverse sort keys %$orig_ref) {
        my $entity = $orig_ref->{ $hidden_entity };
        $xml =~ s/$hidden_entity/$entity/g;
    }
    
    return $xml;
}

sub highlight_text {
    my $xml = shift;

    my $bg = "background-color:#FFFFFF";
    $xml =~ s{<title>Abstract</title>\n<p>}
             {<title>Abstract</title>\n<p style="$bg">};
    
    $bg  =  "background-color:#FFFFFF";

    $xml =~ s{\n<p>(.+?)<list-item><p>}
             {\n<p style="$bg">$1<list-item><p style="$bg">}g;
    $xml =~ s{\n<p>}{\n<p style="$bg">}g;
    $xml =~ s{\n<list-item><p>}{\n<list-item><p style="$bg">}g;

    return $xml;
}

sub create_linked_xml_file {
    my $htmlfile = shift;
    my $xmlfile  = shift;

    my $cont = get_file_contents( $htmlfile );

    # remove all background colors
    $cont =~ s{<p \S+?>}{<p>}g;

    # remove all javascript stuff
    $cont =~ s{(<a href="http://(www\.wormbase|www\.yeastgenome|flybase)\.org/.+?") id=".+?"(>)(.+?)(</a>)<a href=".+?"><sup><img \S+?></sup></a>}
              {$1$3$4$5}g;

    open OUT, '>', $xmlfile or die $!;
    print OUT $cont;
    close OUT;
}

sub get_file_contents {
    my $file = shift;

    undef $/;
    open IN, '<', $file or die $!;
    my $cont = <IN>;
    close IN;
    $/ = "\n";

    return $cont;
}

sub get_hidden_entity {
    my $entity   = shift;
    my $orig_ref = shift;

    my $max_id = scalar keys %$orig_ref;
    my $new_id = $max_id + 1;

    my $hidden_entity = "HIDDEN_ENTITY-$new_id";

    $orig_ref->{ $hidden_entity } = $entity;

    return $hidden_entity;
}

1;
