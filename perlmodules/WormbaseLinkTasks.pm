package WormbaseLinkTasks;

use Moose;
use FindBin qw/$Bin/;
use LWP::UserAgent;
use CGI qw/:standard *table/;
use File::Slurp;
use JSON qw/decode_json/;
use Data::Dumper;
use Log::Log4perl;
use TextpressoGeneralTasks;
use WormbaseLinkGlobals;
use GeneralTasks;
use GeneralGlobals;
use Specs;


# Maybe we want to include the date of the run?
#    # Append the date
#    my $date = `date +%Y-%m-%d`;
#    chomp $date;
#    return "$this/$date";

# I should break this into STDERR and STDOUT logs.
has 'log' => (
    is => 'ro',
    lazy_build => 1,
);

sub _build_log {
    my $self    = shift;
    my $stage   = $self->stage;
    my $log_dir = $self->log_dir;   # Currently, just a master log.

    # Make sure that our log dirs exist
    # $self->_make_dir($self->log_dir);
    # $self->_make_dir($self->log_dir . "/$release");
    
    # $self->_make_dir($self->log_dir . "/$release/steps");
    # $self->_make_dir($self->log_dir . "/$release/steps/$step");

    my $log_config = qq(

		log4perl.rootLogger=INFO, MASTERLOG, MASTERERR, SCREEN

                # MatchTRACE: lowest level for the STEPLOG
                log4perl.filter.MatchTRACE = Log::Log4perl::Filter::LevelRange
                log4perl.filter.MatchTRACE.LevelMin = TRACE
                log4perl.filter.MatchTRACE.AcceptOnMatch = true

                # MatchWARN: Exact match for warnings
                log4perl.filter.MatchWARN = Log::Log4perl::Filter::LevelMatch
                log4perl.filter.MatchWARN.LevelToMatch = WARN
                log4perl.filter.MatchWARN.AcceptOnMatch = true

                # MatchERROR: ERROR and UP
                log4perl.filter.MatchERROR = Log::Log4perl::Filter::LevelRange
                log4perl.filter.MatchERROR.LevelMin = ERROR
                log4perl.filter.MatchERROR.AcceptOnMatch = true

                # MatchINFO: INFO and UP. For SCREEN.
                log4perl.filter.MatchINFO = Log::Log4perl::Filter::LevelRange
                log4perl.filter.MatchINFO.LevelMin = INFO
                log4perl.filter.MatchINFO.AcceptOnMatch = true

                # The SCREEN
                log4perl.appender.SCREEN           = Log::Log4perl::Appender::Screen
                log4perl.appender.SCREEN.mode      = append
                log4perl.appender.SCREEN.layout    = Log::Log4perl::Layout::PatternLayout
		#log4perl.appender.SCREEN.layout.ConversionPattern=[%d %r]%K%F %L %c − %m%n
		log4perl.appender.SCREEN.layout.ConversionPattern=[%d %p]%K%m %n
#		log4perl.appender.Screen.stderr  = 0
                log4perl.appender.SCREEN.Filter   = MatchINFO
         
                # The MASTERLOG: INFO, WARN, ERROR, FATAL
		log4perl.appender.MASTERLOG=Log::Log4perl::Appender::File
		log4perl.appender.MASTERLOG.filename=$log_dir/master.log
		log4perl.appender.MASTERLOG.mode=append
		log4perl.appender.MASTERLOG.layout = Log::Log4perl::Layout::PatternLayout
		log4perl.appender.MASTERLOG.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
                log4perl.appender.MASTERLOG.Filter   = MatchINFO


                # The MASTERERR: ERROR, FATAL
		log4perl.appender.MASTERERR=Log::Log4perl::Appender::File
		log4perl.appender.MASTERERR.filename=$log_dir/master.err
		log4perl.appender.MASTERERR.mode=append
		log4perl.appender.MASTERERR.layout = Log::Log4perl::Layout::PatternLayout
		log4perl.appender.MASTERERR.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
                log4perl.appender.MASTERERR.Filter   = MatchERROR
 		);

#    my $log_config = qq(
#
#		log4perl.rootLogger=INFO, MASTERLOG, MASTERERR, STEPLOG, STEPERR, SCREEN
#
#                # MatchTRACE: lowest level for the STEPLOG
#                log4perl.filter.MatchTRACE = Log::Log4perl::Filter::LevelRange
#                log4perl.filter.MatchTRACE.LevelMin = TRACE
#                log4perl.filter.MatchTRACE.AcceptOnMatch = true
#
#                # MatchWARN: Exact match for warnings
#                log4perl.filter.MatchWARN = Log::Log4perl::Filter::LevelMatch
#                log4perl.filter.MatchWARN.LevelToMatch = WARN
#                log4perl.filter.MatchWARN.AcceptOnMatch = true
#
#                # MatchERROR: ERROR and UP
#                log4perl.filter.MatchERROR = Log::Log4perl::Filter::LevelRange
#                log4perl.filter.MatchERROR.LevelMin = ERROR
#                log4perl.filter.MatchERROR.AcceptOnMatch = true
#
#                # MatchINFO: INFO and UP. For SCREEN.
#                log4perl.filter.MatchINFO = Log::Log4perl::Filter::LevelRange
#                log4perl.filter.MatchINFO.LevelMin = INFO
#                log4perl.filter.MatchINFO.AcceptOnMatch = true
#
#                # The SCREEN
#                log4perl.appender.SCREEN           = Log::Log4perl::Appender::Screen
#                log4perl.appender.SCREEN.mode      = append
#                log4perl.appender.SCREEN.layout    = Log::Log4perl::Layout::PatternLayout
#		#log4perl.appender.SCREEN.layout.ConversionPattern=[%d %r]%K%F %L %c − %m%n
#		log4perl.appender.SCREEN.layout.ConversionPattern=[%d %p]%K%m %n
##		log4perl.appender.Screen.stderr  = 0
#                log4perl.appender.SCREEN.Filter   = MatchINFO
#         
#                # The MASTERLOG: INFO, WARN, ERROR, FATAL
#		log4perl.appender.MASTERLOG=Log::Log4perl::Appender::File
#		log4perl.appender.MASTERLOG.filename=$log_dir/$release/master.log
#		log4perl.appender.MASTERLOG.mode=append
#		log4perl.appender.MASTERLOG.layout = Log::Log4perl::Layout::PatternLayout
#		log4perl.appender.MASTERLOG.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
#                log4perl.appender.MASTERLOG.Filter   = MatchINFO
#
#
#                # The MASTERERR: ERROR, FATAL
#		log4perl.appender.MASTERERR=Log::Log4perl::Appender::File
#		log4perl.appender.MASTERERR.filename=$log_dir/$release/master.err
#		log4perl.appender.MASTERERR.mode=append
#		log4perl.appender.MASTERERR.layout = Log::Log4perl::Layout::PatternLayout
#		log4perl.appender.MASTERERR.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
#                log4perl.appender.MASTERERR.Filter   = MatchERROR
#
#                # The STEPLOG: TRACE to get everything.
#		log4perl.appender.STEPLOG=Log::Log4perl::Appender::File
#		log4perl.appender.STEPLOG.filename=$log_dir/$release/steps/$step/step.log
#		log4perl.appender.STEPLOG.mode=append
#		log4perl.appender.STEPLOG.layout = Log::Log4perl::Layout::PatternLayout
#		#log4perl.appender.STEPLOG.layout.ConversionPattern=[%d %p]%K%l − %r %m%n
#		log4perl.appender.STEPLOG.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
#		#log4perl.appender.STEPLOG.layout.ConversionPattern=[%d %p]%K %n	       
#                log4perl.appender.STEPLOG.Filter   = MatchTRACE
#
#                # The STEPERR: ERROR and up
#		log4perl.appender.STEPERR=Log::Log4perl::Appender::File
#		log4perl.appender.STEPERR.filename=$log_dir/$release/steps/$step/step.err
#		log4perl.appender.STEPERR.mode=append
#		log4perl.appender.STEPERR.layout = Log::Log4perl::Layout::PatternLayout
#		#log4perl.appender.STEPERR.layout.ConversionPattern=[%d %p]%K%l − %r %m%n
#		log4perl.appender.STEPERR.layout.ConversionPattern=[%d %p]%K%m (%M [%L])%n
#		#log4perl.appender.STEPERR.layout.ConversionPattern=[%d %p]%K %n	       
#                log4perl.appender.STEPERR.Filter   = MatchERROR
#		);
    
    Log::Log4perl::Layout::PatternLayout::add_global_cspec('K',
							       sub {
								   
								   my ($layout, $message, $category, $priority, $caller_level) = @_;
								   # FATAL, ERROR, WARN, INFO, DEBUG, TRACE
								   return "    "  if $priority eq 'DEBUG';
								   return "    "  if $priority eq 'INFO';
								   return "  "  if $priority eq 'WARN';  # potential errors
								   return " !  "  if $priority eq 'ERROR'; # errors
								   return " !  "  if $priority eq 'FATAL';  # fatal errors
								   return "    ";
							   });
    
    Log::Log4perl::init(\$log_config) or die "Couldn't create the Log::Log4Perl object";
        
    my $logger = Log::Log4perl->get_logger('rootLogger');
    return $logger;	
}


# Logging options
has 'log_dir' => (
    is => 'ro',
    lazy_build => 1,
    );

sub _build_log_dir {
    my $self   = shift;
    my $directory = $self->output_root;
    return $directory;
}



has 'stage' => (
    is => 'rw',
    );

# Sometimes we are passed a file;
# Other times we need the root container.
# This is the input file (plus full path),
# an anomaly of the pipeline interface.
has 'input_file' => (
    is => 'rw',
    lazy_build => 1,
    );


#################################################
#
#    (Output) directories
#
#    Created dynamically based on the filename
#    from incoming_xml/
#
#################################################

# This is the top-level output directory.
# The path is:
# output/CLIENT/ID/
# with directories therein for firstpass, qaqc, etc
has 'output_root' => (
    is => 'rw',    
    lazy_build => 1,
    );

sub _build_output_root {
    my $self = shift;

    my $output = join("/","$Bin/../output",$self->client,$self->file_id);
    unless (-e $output) {
	system("mkdir -p $output") 
	    or $self->log->warn("Couldn't create the top-level output directory at $output");
    }
    return $output;
}

# An absolute path to the directory of the current stage 
#  (stage is a symbolic name passed to the constructor)
# output/CLIENT/ID/STAGE
has 'stage_directory' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_stage_directory {
    my $self = shift;
    my $stage = $self->stage;
    my $dir = join("/",$self->output_root,$stage);
    unless (-e $dir) {
	system("mkdir -p $dir") or $self->log->warn("Couldn't create $dir: $!");
    }
    return $dir;
}

# Client is extracted from the input file.
# It is expected to be of the format:
# [CLIENT]-[ID].xml
has 'client' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_client {
    my $self = shift;
    my $file = $self->input_file;
    
    # Get the filename from the full path.
    my @e = split(/\//, $file);
    my $filename = pop @e;
    
    # Get the base identifier.
    $filename =~ /(.*)\-.*/;
    my $client = $1;
    return $client; 
}


# Filename base is *just* the file name without suffix.
# It is used to create suitable paths and files.
# It is expected that the filename base is all digits.
has 'filename' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_filename {
    my $self = shift;
    my $file = $self->input_file;
    
    # Get the filename from the full path.
    my @e = split(/\//, $file);
    my $filename = pop @e;
    
    # Get the filename less suffix (CLIENT-ID)
    $filename =~ /(.*)\./;
    return $1;    
}


# Filename base is *just* the file name without suffix.
# It is used to create suitable paths and files.
# It is expected that the filename base is all digits.
has 'file_id' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_file_id {
    my $self = shift;
    my $file = $self->input_file;
    
    # Get the filename from the full path.
    my @e = split(/\//, $file);
    my $filename = pop @e;
    
    # Get the base identifier.
    $filename =~ /(\d+)/;
    return $1;
}


has 'log_file' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_log_file {
    my $self = shift;
    
    my $stage = $self->stage;
    my $log_file = join('/',$self->stage_directory,$self->filename . '.log');
    if (-e $log_file) {
	die "log file $log_file already exists. Won't run again!\n";
    }
    return $log_file;
}

has 'report_file' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_report_file {
    my $self = shift;
    return $self->filename . '-report.html';
}

has 'lexicon_file' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_lexicon_file {
    my $self = shift;
    # TH: Hard-coded. Sorry, this is lame!
    # The Lexicon should probably be client specific.
    my $lexicon = "$Bin/../data/lexicon/lexicon";
    return $lexicon;
}




has 'linked_xml' => (
    is         => 'rw',
    lazy_build => 1,
    );

sub _build_linked_xml {    
    my $self = shift;    
    # TH: Slurp up linked xml and spit it out. Very odd.
    undef($/); open (IN, "<" . $self->input_file) or $self->log->die("couldn't copy the linked xml file: $!");
    my $linked_xml = <IN>; close (IN); $/ = "\n";
    return $linked_xml;
}

has 'wormbase_paper_id' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_wormbase_paper_id {
    my $self = shift;
#    my $xml_filename = $self->xml_filename;
#    
#    $xml_filename =~ /(\d+)/;
#    my $genetics_id = $1;

    my $genetics_id = $self->file_id;

    # This page is protected.
    my $web_page = "http://tazendra.caltech.edu/~postgres/cgi-bin/author_fp_display.cgi?afp_jfp=jfp";
    my $contents = TextpressoGeneralTasks::getwebpage($web_page);
    my @lines = split(/\n/, $contents);
    
    my $wbpaper_id;
    for (my $i=0; $i<@lines; $i++) {
        if ($lines[$i] =~ /\.$genetics_id<\/td>/) {
            # this line is like 
            # <td align="center">doi10.1534/genetics.111.128421</td>
            #
            # the next line is like 
            # <td align="center"><a href="http://tazendra.caltech.edu...">00032266</a></td>
            $lines[$i+1] =~ /\>(\d+)\</;
            $wbpaper_id = "WBPaper" . $1;
            last;
        }
    }
    return 'unknown id-no access to tazendra';
    return $wbpaper_id;
}

# Uh, this becomes global so headers remain set?
has 'my_user_agent' => (
    is => 'rw',
    lazy_build => 1,
    );

sub _build_my_user_agent {
    my $self = shift;
    my $ua = LWP::UserAgent->new();
    $ua->agent("GSA Markup Pipeline/1.0");
    return $ua;
}

has 'email_sender' => (
    is => 'ro',
    lazy_build => 1,
    );

sub _build_email_sender {
    my $self = shift;    
    my $emails = read_file(Specs::EMAIL_DIR . '/developers.txt');
    return $emails;
}

has 'email_receivers' => (
    is => 'ro',
    lazy_build => 1,
    );

sub _build_email_receivers {
    my $self = shift;
    my @emails = read_file(Specs::EMAIL_DIR . '/curators.txt');

    # keep the sender apprised of all emails.
    push @emails,$self->email_sender;
    return @emails;
}

has 'email_final_receivers' => (
    is => 'ro',
    lazy_build => 1,
    );

sub _build_email_final_receivers {
    my $self = shift;
    my @emails = read_file(Specs::EMAIL_DIR . '/final.txt');

    # keep the sender apprised of all emails.
    push @emails,$self->email_sender;
    return @emails;
}




# ------------------------


sub findAndLinkObjects {
    my $self               = shift;
    my $xml                = shift;
    my $tok_txt            = shift;
    my $xml_format         = shift;

    my ($lexicon,$sorted_entries) = $self->loadLexicon;
    my $wbpaper_id                = $self->wormbase_paper_id; 
#    my $gsa_id                    = $self->gsa_id;
    my $gsa_id = $self->file_id;
   
    $self->log->info("Linking objects in $gsa_id");
    
    my $linked_xml = $xml;
    
    # hash used for avoiding sub-string matches
    my %orig = (); # key: hidden name, value: entity
    
    for my $entity_name (@$sorted_entries) {
	
        # matching happens in $tok_txt; links added to $linked_xml
        if ($tok_txt =~ /\Q$entity_name\E/) { 
	    
            my $class = get_entity_class( keys %{$lexicon->{$entity_name}} );
	    
            # generic URL; is changed for special cases below.
            my $url = "http://www.wormbase.org/db/get?name=$entity_name;class=$class";

            if (
                ($linked_xml !~ m{(<I>)( ?)(\Q$entity_name\E)( |,)?(</I>-test)}) or 
                ($linked_xml !~ m{(<I>)( ?)(\Q$entity_name\E)( |,)?(</I>\stest)}) or 
                ($linked_xml !~ m{ ([\=]\s*<I>)( ?)(\Q$entity_name\E)( |,)?(</I>)}) or 
                ($linked_xml !~ m{ (<I>)( ?)(\Q$entity_name\E)( |,)?(</I>\s*[\=])}) or 
                ($linked_xml !~ m{(<italic>)( ?)(\Q$entity_name\E)( |,)?(</italic>-test)}) or 
                ($linked_xml !~ m{(<italic>)( ?)(\Q$entity_name\E)( |,)?(</italic>\stest)}) or 
                ($linked_xml !~ m{ ([\=]\s*<italic>)( ?)(\Q$entity_name\E)( |,)?(</italic>)}) or 
                ($linked_xml !~ m{ (<italic>)( ?)(\Q$entity_name\E)( |,)?(</italic>\s*[\=])})  
		){                        
		
		if  (
		    ($linked_xml !~ m{ (::<italic>)( ?)(\Q$entity_name\E)( |,)?(</italic>)}) or
		    ($linked_xml !~ m{ (<italic>)( ?)(\Q$entity_name\E)( |,)?(</italic>::)}) or 
		    ($linked_xml !~ m{ (::<I>)( ?)(\Q$entity_name\E)( |,)?(</I>)}) or
		    ($linked_xml !~ m{ (<I>)( ?)(\Q$entity_name\E)( |,)?(</I>::)})  
		    )  {
		    
		    # skip what won't be linked
		    if ( $class eq "Gene" || $class eq "Protein" ) {
			next if ($linked_xml !~ /\b(\Q$entity_name\E)(p?)\b/);
		    }
		    else {
			next if ($linked_xml !~ /\b\Q$entity_name\E\b/);
		    }
		    
		    $self->log->info("... found $class '$entity_name'");
		    
		    if ( $class eq "Gene" || $class eq "Protein" ) {
			$url = "http://www.wormbase.org/db/get?name=$entity_name;class=Gene";
			
			# hide matched entity to avoid future sub-string matches
			# Hidden entities are replaced with originals once matching is done.
			$linked_xml = $self->link_entity_in_xml($linked_xml, $entity_name, $url, \%orig);
			
			# if there is a 'p' after gene name, link it to the gene
#                $entity_name .= 'p';
#                $linked_xml = $self->link_entity_in_xml($linked_xml, $entity_name, $url, \%orig);
		    } 
		    
		    elsif (    $class eq "Strain"
			       || $class eq "Clone"
			       || $class eq "Transgene"
			       || $class eq "Rearrangement"
			       || $class eq "Sequence"
#                    || $class eq "Anatomy_term"
#                    || $class eq "Anatomy_name"
			) {
			$linked_xml = $self->link_entity_in_xml($linked_xml, $entity_name, $url, \%orig);
		    }
		    
		    elsif ($class eq "Variation") {
			my $allele_root = $self->removeAlleleSuffix($entity_name);
			$url = "http://www.wormbase.org/db/get?name=$allele_root;class=$class";
			$linked_xml = $self->link_variation_in_xml($linked_xml, $entity_name, $allele_root, $url, \%orig);
		    }
		    
		    elsif ($class eq "Phenotype") {
			my $phenotype_id = $lexicon->{$entity_name}{$class}; 
			$url = "http://www.wormbase.org/db/get?name=$phenotype_id;class=$class";
			$linked_xml = $self->link_entity_in_xml($linked_xml, $entity_name, $url, \%orig);
		    }
		}
	    }
	}
	
	# special case for Variation. entries like snp_2L52[1]
	elsif ($entity_name =~ /^snp_/) {
	    if ($tok_txt =~ /($entity_name)/i) {
		for my $class (keys %{$lexicon->{$entity_name}}) { # only Variation here.
		    
		    $self->log->info("... $class \'$entity_name\' (special case for Variation)");
		    
		    my $allele_root = $self->removeAlleleSuffix($entity_name);
		    my $url = "http://www.wormbase.org/db/get?name=$allele_root;class=Variation";
		    
		    $linked_xml = $self->link_variation_in_xml($linked_xml, $entity_name, $allele_root, $url, \%orig);
		}
	    }
	}
		
	$tok_txt =~ s/\Q$entity_name\E/ /g;
    }
    
    $linked_xml = $self->linkSpecialCasesUsingPatternMatch($linked_xml, $lexicon, \%orig);
    
    $linked_xml = GeneralTasks::replace_hidden_entities($linked_xml, \%orig);
    
# upon Karen's request from 04/10/12 don't do any author linking for now.
#    $linked_xml = linkAuthorNames($linked_xml, $wbpaper_id, $xml_format);
    
    $linked_xml = $self->removeUnwantedLinks($linked_xml, $xml_format);
    
    $linked_xml = $self->escape_urls( $linked_xml );
    
    $self->log->die("FATAL ERROR: XML text changed during linking!")
        if ( ! original_txt_is_preserved($xml, $linked_xml, $gsa_id) );
    
    $linked_xml = GeneralTasks::highlight_text( $linked_xml );
    
    return $linked_xml;
}

# Deprecated?
#sub getEntityClass {
#    my $link = shift;
#
#    if ( ($link =~ /(Gene)/) || ($link =~ /(Strain)/) || ($link =~ /(Clone)/) || ($link =~ /(Transgene)/) ||
#         ($link =~ /(Rearrangement)/) || ($link =~ /(Sequence)/) || ($link =~ /(Phenotype)/) ) {
#        return $1;
#    } elsif ($link =~ /Variation/i) {
#        return "Variation";
##    } elsif ($link =~ /anatomy/i) {
##        return "Anatomy";
#    } elsif ($link =~ /person/i) {
#        return "Person";
#    } elsif ($link =~ /GO\_term/i) {
#        return "GO";
#    }
#
#    die "died: The link $link does not have a valid entity class\n";
#}

sub link_entity_in_xml {
    my $self     = shift;
    my $xml      = shift;
    my $entity   = shift;
    my $url      = shift;
    my $orig_ref = shift;

    my $w_before; 
    my $w_after;
    my $repl_after;
    my $repl_before;
    my $after;
    my $before;

# Replace the double colons in the text so that the linking routines works.
    $xml =~ s/\:\:/DOUBLECOLON/g;

    my $hidden_entity = GeneralTasks::get_hidden_entity( $entity, $orig_ref );
    (my $hidden_url = $url) =~ s/\Q$entity\E/$hidden_entity/;
    
    my $jsid = 1;

    foreach ($xml =~ /\b\Q$entity\E\b/g) {
        ( $w_before, $w_after ) = $xml =~ m/(\w+)\s*\Q$entity\E\s*(\w+)/;
        
        if (( index($w_before,"DOUBLECOLON") == -1 ) and ( index($w_after,"DOUBLECOLON") == -1 )){
        my $repl =  "<a href=\"$hidden_url\" id=\"$hidden_entity-$jsid\">$hidden_entity</a>"
                  . "<a href=\"javascript:removeLinkAfterConfirm('$hidden_entity-$jsid')\">"
                  . "<sup><img src=\"/gsa/img/minus.png\"/></sup>"
                  . "</a>";
        $self->log->debug("   link_entity_in_xml: $entity");
#        print "before: $w_before\n";
#        print "after:  $w_after\n";

        $xml =~ s/\b\Q$entity\E\b/$repl/;
        $repl_after = $repl;
        $repl_after .="\<\/italic\>";
        $repl_after .= "DOUBLECOLON";
        $repl_before = "DOUBLECOLON";
        $repl_before .= "\<italic\>";
        $repl_before .= $repl;

#        print "repl = $repl\n";
#        print "repl_before = $repl_before\n";
#        print "repl_after = $repl_after\n";

        $after = "\<\/italic\>";
        $after .= "DOUBLECOLON";
        $after .= "\b\Q$entity\E\b";        

        $before = "DOUBLECOLON";
        $before .= "\<italic\>";
        $before .= "\b\Q$entity\E\b"; 

        $xml =~ s/$repl_after/$after/;
        $xml =~ s/$repl_before/$before/;
#        print "xml = \n";
#        print "$xml\n";
#        print "\n\n";

#        if ($xml =~ /DOUBLECOLON/) {
#            print "DOUBLECOLON\: \t $xml\n";
#        }

        $jsid++;
        }
    }

# Place the double colons back into the text
        $xml =~s/DOUBLECOLON/\:\:/g;

    return $xml;
}


sub link_variation_in_xml {
    my $self        = shift;
    my $xml         = shift;
    my $entity      = shift;
    my $name_in_url = shift;
    my $url         = shift;
    my $orig_ref    = shift;

    my $w_before; 
    my $w_after;
    my $repl_after;
    my $repl_before;
    my $after;
    my $before;

# Replace the double colons in the text so that the linking routines works.
    $xml =~ s/\:\:/DOUBLECOLON/g;

    my $hidden_name_in_url = GeneralTasks::get_hidden_entity( $name_in_url, $orig_ref );
    (my $hidden_url = $url) =~ s/$name_in_url/$hidden_name_in_url/;
    
    my $hidden_entity = GeneralTasks::get_hidden_entity( $entity, $orig_ref );

    my $jsid = 1;
    foreach ($xml =~ /\b$entity\b/g) {
       ( $w_before, $w_after ) = $xml =~ m/(\w+)\s*\Q$entity\E\s*(\w+)/;
        if (( index($w_before,"DOUBLECOLON") == -1 ) and ( index($w_after,"DOUBLECOLON") == -1 )){
        my $repl =  "<a href=\"$hidden_url\" id=\"$hidden_entity-$jsid\">$hidden_entity</a>"
                  . "<a href=\"javascript:removeLinkAfterConfirm('$hidden_entity-$jsid')\">"
                  . "<sup><img src=\"/gsa/img/minus.png\"/></sup>"
                  . "</a>";
    
        $xml =~ s/\b$entity\b/$repl/;

        $repl_after = $repl;
        $repl_after .="\<\/italic\>";
        $repl_after .= "DOUBLECOLON";
        $repl_before = "DOUBLECOLON";
        $repl_before .= "\<italic\>";
        $repl_before .= $repl;

        $after = "\<\/italic\>";
        $after .= "DOUBLECOLON";
        $after .= "\b\Q$entity\E\b";        

        $before = "DOUBLECOLON";
        $before .= "\<italic\>";
        $before .= "\b\Q$entity\E\b"; 

        $xml =~ s/$repl_after/$after/;
        $xml =~ s/$repl_before/$before/;

        $jsid++;
     }
    }
       $xml =~s/DOUBLECOLON/\:\:/g;

    return $xml;
}


sub escape_urls {
    my $self = shift;
    my $xml = shift;

    use URI::Escape;

    my $xmlcopy = $xml;
    while ($xmlcopy =~ m{"http://www\.wormbase\.org/db/get\?name=(.+?);class=.+?"}g) {
        my $name_in_link = $1;
        my $esc_name = uri_escape( $name_in_link );
        if ($esc_name ne $name_in_link) {
            $xml =~ s{"(http://www\.wormbase\.org/db/get\?name=)$name_in_link(;class=.+?)"}{"$1$esc_name$2"}g;
        }

        $xmlcopy =~ s{"http://www\.wormbase\.org/db/get\?name=$name_in_link;class=.+?"}{ }g;
    }

    return $xml;
}

sub linkAuthorNamesNlmXml {
    my $xml = shift;
    my $wbpaper_id = shift;

    my $xmlcopy = $xml;

    print "Linking author names...\n\n";
    while ($xmlcopy =~ /<contrib contrib-type="author"( corresp="yes")?><name><surname>(.+?)<\/surname><given-names>(.+?)<\/given-names>/g) {
        my $surname = $2;
        my $given_names = $3;
        my $full_name = "$given_names $surname";
        print "fullname = $full_name\n";
        
        my $url_encoded_name = uri_escape($full_name);
        $url_encoded_name =~ s/\.//g; # WormBase does not have the aliases with a period after middle name!
        my $url = "http://www.wormbase.org/db/misc/person?name=$url_encoded_name;paper=$wbpaper_id";
        print "url = $url\n\n";

        # $xml =~ s/(<contrib contrib-type="author"( corresp="yes")?><name><surname>$surname<\/surname><given-names>$given_names<\/given-names><\/name>)/$1<ext-link ext-link-type="uri" xlink:href="$url"\/>/;
        $xml =~ s/<contrib contrib-type="author"( corresp="yes")?><name><surname>$surname<\/surname><given-names>$given_names<\/given-names><\/name>/<contrib contrib-type="author"$1><name><surname><a href="$url">$surname<\/a><\/surname><given-names><a href="$url">$given_names<\/a><\/given-names><\/name>/;
    }

    return $xml;
}

sub linkAuthorNamesFlatXml {
    my $xml = shift;
    my $wbpaper_id = shift;

    $xml =~ /\<Authors\>(.+)\<\/Authors\>/;
    my $author_names = $1; # <au_fname>Feifan</au_fname> <au_surname>Zhang</au_surname>, 
    # <au_fname>M. Maggie</au_fname> <au_surname>O&#x2019;Meara</au_surname>, and 
    # <au_fname>Oliver</au_fname> <au_surname>Hobert</au_surname><cite_fn><SUP>1</SUP></cite_fn> 
    
    while ($author_names =~ /<au_fname>(.+?)<\/au_fname> <au_surname>(.+?)<\/au_surname>/g) {
        my $firstname = $1;
        my $lastname  = $2;

        my $clean_lastname = $lastname;
        $clean_lastname =~ s/\,$//; # DJS keeps commas inside the tags sometimes!

        my $clean_firstname = $firstname;
        $clean_firstname =~ s/\.//g; # WB does not have period in first or middle names 

        my $fullname  = "$clean_firstname $clean_lastname";
        my $url_encoded_name = uri_escape($fullname);
        my $url = "http://www.wormbase.org/db/misc/person?name=$url_encoded_name;paper=$wbpaper_id";

        $xml =~ s/<au_fname>$firstname<\/au_fname> <au_surname>$lastname<\/au_surname>/<au_fname><a href="$url">$firstname<\/a><\/au_fname> <au_surname><a href="$url">$lastname<\/a><\/au_surname>/;
    }

    return $xml;
}

sub linkAuthorNamesFlatXmlOld {
    my $xml = shift;
    my $wbpaper_id = shift;

    $xml =~ /\<Authors\>(.+)\<\/Authors\>/;
    my $author_names = $1; # Meredith J. Ezak,* Elizabeth Hong,<SUP>1</SUP> Angela Chaparro-Garcia<SUP>1,2</SUP> and Denise M. Ferkey<SUP>3</SUP>
    # Sumeet Sarin,* Vincent Bertrand,* Henry Bigelow,*<SUP>,&#x2020;</SUP> Alexander Boyanov,* Maria Doitsidou,* Richard Poole,* Surinder Narula* 
    # and Oliver Hobert*
    
    # remove all XML <SUP> tags and their contents
    $author_names =~ s/\<SUP\>.+?\<\/SUP\>//g; # Meredith J. Ezak, Elizabeth Hong, Angela Chaparro-Garcia and Denise M. Ferkey

    # remove all the asterisks
    $author_names =~ s/\*//g;

    # remove other tags like <B>, <I>, etc.,
    $author_names =~ s/\<\/?.+?\>//g;

    my @entries = split (/\,\s+/, $author_names);
    my $last_two_names = pop @entries;
    (my $author_1, my $author_2) = split(/ and /, $last_two_names);
    if ( ($author_1 =~ /\S/) && ($author_2 =~ /\S/) ) { # needed since sometimes there is no 'and' at the end!
        push @entries, $author_1;
        push @entries, $author_2;
    } else { # put the last fullname back
        push @entries, $last_two_names;
    }

    print "Author names\n";
    for my $fullname (@entries) {
        my $url_encoded_name = uri_escape($fullname);
        $url_encoded_name =~ s/\.//g; # WormBase does not have the aliases with a period after middle name!
        my $url = "http\:\/\/www\.wormbase\.org\/db\/misc\/person\?name=$url_encoded_name\;paper=$wbpaper_id";

        # this is for DJS; middle initial is part of first name
        my @subnames = split(/\s/, $fullname);
        my $last_name = pop @subnames;
        my $first_name = join(" ", @subnames);
        print "first_name = $first_name\n";
        print "last_name  = $last_name\n";
        
        $xml =~ s/$fullname/\<a href=\"$url\"\>$first_name\<\/a\> \<a href=\"$url\"\>$last_name\<\/a\>/g;
    }
    return $xml;
}

# use URI::Escape escape_uri Perl built-in
#sub encodeInHtml {
#    my $string = shift;
#
#    $string =~ s/ /\%20/g;
#    $string =~ s/'/\%27/g;
#    $string =~ s/\:/\%3A/g;
#    $string =~ s/\Q&#x00E9;\E/e/g; # e with an accent - occurs in author names
#    $string =~ s/\Q&#x2019;\E/\%27/g; # single quote
#
#    return $string;
#}

sub removeAlleleSuffix {
    my $self = shift;
    my $entity_name = shift;
    
    my $root = $entity_name;
    for my $suffix ( @{(WormbaseLinkGlobals::SY_ALLELE_SUFFIXES)} ) {
        if ($entity_name =~ /^(.+)$suffix$/) {
            $root = $1;
            last;
        }
    }
    return $root;
}

sub linkSpecialCasesUsingPatternMatch {
    my $self = shift;
    $self->log->info("** Linking special cases **");
    my $xml = shift;
    my $lexicon_ref = shift;
    my $orig_ref = shift;
    
    $xml = $self->linkSpecialVariationsUsingPatternMatch($xml, $lexicon_ref, $orig_ref);
    $xml = $self->linkSpecialGenesUsingPatternMatch($xml, $lexicon_ref, $orig_ref);
    return $xml;
}


sub linkSpecialGenesUsingPatternMatch {
    my $self        = shift;

    $self->log->info(" ** Linking special genes using pattern match **");
    my $xml         = shift;
    my $lexicon_ref = shift;
    my $orig_ref    = shift;

    my $w_before; 
    my $w_after;
    my $repl_after;
    my $repl_before;
    my $after;
    my $before;

    # link transgenes like sdf-9V to sdf-9 gene page
    while ($xml =~ /\b([a-z]{1,4}-\d+)(V)\b/g) { 
        my $gene = $1;
        my $suff = $2;

        next if (! defined( $lexicon_ref->{$gene}{"Gene"} ));

        my $url = "http://www.wormbase.org/db/get?name=$gene;class=Gene";
        #$xml =~ s/\b($gene$suff)\b/\<a href=\"$url\"\>$1\<\/a\>/g;
        $xml = $self->link_entity_in_xml( $xml, 
					  $gene . $suff,
					  $url,
					  $orig_ref
	    );
    }

    # link double mutant genes with no delimiters. eg: osm-9ocr-2
    while ($xml =~ /\b([a-zA-Z]{3,4}-\d+)([a-zA-Z]{3,4}-\d+)\b/g) { 
        my ($gene1, $gene2) = ($1, $2);
        
        my $url1; 
        if ( defined($lexicon_ref->{$gene1}{"Gene"}) ) { 
            $url1 = "http://www.wormbase.org/db/get?name=$gene1;class=Gene";
        }

        my $url2;
        if ( defined($lexicon_ref->{$gene2}{"Gene"}) ) {
            $url2 = "http://www.wormbase.org/db/get?name=$gene2;class=Gene";
        }

        if ($url1 && $url2) {
            $self->log->info("   linking $gene1$gene2");
            $xml =~ s/\:\:/DOUBLECOLON/g;
            my $hidden_entity = GeneralTasks::get_hidden_entity( $gene1, $orig_ref );
            (my $hidden_url = $url1) =~ s/\Q$gene1\E/$hidden_entity/;
            my $jsid = 1;
            foreach ($xml =~ /\b\Q$gene1\E/g) {
                        ( $w_before, $w_after ) = $xml =~ m/(\w+)\s*\Q$gene1\E\s*(\w+)/;
             if (( index($w_before,"DOUBLECOLON") == -1 ) and ( index($w_after,"DOUBLECOLON") == -1 )){
                my $repl =  "<a href=\"$hidden_url\" id=\"$hidden_entity-$jsid\">$hidden_entity</a>"
                          . "<a href=\"javascript:removeLinkAfterConfirm('$hidden_entity-$jsid')\">"
                          . "<sup><img src=\"/gsa/img/minus.png\"/></sup>"
                          . "</a>";
                $xml =~ s/\b\Q$gene1$gene2\E\b/$repl$gene2/;
                $jsid++;
            }
           }

            $hidden_entity = GeneralTasks::get_hidden_entity( $gene2, $orig_ref );
            ($hidden_url = $url2) =~ s/\Q$gene2\E/$hidden_entity/;
            $jsid = 1;
            foreach ($xml =~ m{</a>\Q$gene2\E\b}g) {
            ( $w_before, $w_after ) = $xml =~ m/(\w+)\s*\Q$gene2\E\s*(\w+)/;
             if (( index($w_before,"DOUBLECOLON") == -1 ) and ( index($w_after,"DOUBLECOLON") == -1 )){
                my $repl =  "<a href=\"$hidden_url\" id=\"$hidden_entity-$jsid\">$hidden_entity</a>"
                          . "<a href=\"javascript:removeLinkAfterConfirm('$hidden_entity-$jsid')\">"
                          . "<sup><img src=\"/gsa/img/minus.png\"/></sup>"
                          . "</a>";
                $xml =~ s{</a>\Q$gene2\E\b}{</a>$repl};
                $jsid++;
             }
            }
             $xml =~s/DOUBLECOLON/\:\:/g;
        } 
        elsif ($url1) {
	    $self->log->info("  linking $gene1");
            $xml =~ s/\:\:/DOUBLECOLON/g;
            my $hidden_entity = GeneralTasks::get_hidden_entity( $gene1, $orig_ref );
            (my $hidden_url = $url1) =~ s/\Q$gene1\E/$hidden_entity/;
            my $jsid = 1;
            foreach ($xml =~ /\b\Q$gene1\E/g) {
            ( $w_before, $w_after ) = $xml =~ m/(\w+)\s*\Q$gene1\E\s*(\w+)/;
             if (( index($w_before,"DOUBLECOLON") == -1 ) and ( index($w_after,"DOUBLECOLON") == -1 )){
                my $repl =  "<a href=\"$hidden_url\" id=\"$hidden_entity-$jsid\">$hidden_entity</a>"
                          . "<a href=\"javascript:removeLinkAfterConfirm('$hidden_entity-$jsid')\">"
                          . "<sup><img src=\"/gsa/img/minus.png\"/></sup>"
                          . "</a>";
                $xml =~ s/\b\Q$gene1$gene2\E\b/$repl$gene2/;
                $jsid++;
             }
            }
           $xml =~s/DOUBLECOLON/\:\:/g;
        } 
        elsif ($url2) { 
            $self->log->info("   linking $gene2");
            $xml =~ s/\:\:/DOUBLECOLON/g;
            my $hidden_entity = GeneralTasks::get_hidden_entity( $gene2, $orig_ref );
            (my $hidden_url = $url2) =~ s/\Q$gene2\E/$hidden_entity/;
            my $jsid = 1;
            foreach ($xml =~ m{\b\Q$gene1$gene2\E\b}g) {
            ( $w_before, $w_after ) = $xml =~ m/(\w+)\s*\Q$gene2\E\s*(\w+)/;
             if (( index($w_before,"DOUBLECOLON") == -1 ) and ( index($w_after,"DOUBLECOLON") == -1 )){
                my $repl =  "<a href=\"$hidden_url\" id=\"$hidden_entity-$jsid\">$hidden_entity</a>"
                          . "<a href=\"javascript:removeLinkAfterConfirm('$hidden_entity-$jsid')\">"
                          . "<sup><img src=\"/gsa/img/minus.png\"/></sup>"
                          . "</a>";
                $xml =~ s{\b\Q$gene1$gene2\E\b}{$gene1$repl};
                $jsid++;
             }
            }
                    $xml =~s/DOUBLECOLON/\:\:/g; 
        }
    }

    # link the 11 part in RGS-10/11 to RGS-11 gene page
    # link the -2 part in ZIM-1, -2 to ZIM-2 page
    my $xmlcopy = $xml;
    while ($xml =~ m{((<a href=\S+?;class=Gene" \S+?>(\S+?)</a><a \S+?><sup><img \S+?></sup></a>)(/|, |; )(-?)(\d+))}g) {
        my $full_expression    = $1; # <a href="http://www.wormbase.org/db/get?name=RGS-10;class=Gene">RGS-10</a>/11 
        my $linked_first_part  = $2; # <a href="http://www.wormbase.org/db/get?name=RGS-10;class=Gene">RGS-10</a>
        my $hidden_first_gene  = $3; # RGS-10
        my $separator          = $4; # / or comma followed by space
        my $hyphen             = $5; # not defined in RGS-10/11 example
        my $second_gene_number = $6; # 11

        my $first_gene = $orig_ref->{ $hidden_first_gene };

        $self->log->info("  Matched full expression = $full_expression");
        $self->log->info("  Linked first part       = $linked_first_part");
        $self->log->info("  first gene              = $first_gene");
	$self->log->info("  second genenumber       = $second_gene_number");
	
	(my $gene_prefix = $first_gene) =~ s/\d+//;
        my $second_gene = $gene_prefix . $second_gene_number;
        $self->log->info("  Second gene             = $second_gene");
        my $new_url = "http://www.wormbase.org/db/get?name=$second_gene;class=Gene";
        
        if ($hyphen) {
            $self->log->info("  Linking \'$hyphen$second_gene_number\' in $full_expression to $new_url");
            $xmlcopy =~ s{\Q$full_expression\E}
                        {$linked_first_part$separator<a href="$new_url">$hyphen$second_gene_number</a>};
        } else {
            #open (OUT, ">temp");
            #print OUT "$xml";
            #close (OUT);
            $self->log->info("   Linking \'$second_gene_number\' in $full_expression to $new_url");
            $xmlcopy =~ s{\Q$full_expression\E}
                         {$linked_first_part$separator<a href="$new_url">$second_gene_number</a>};
            #open (OUT, ">temp2");
            #print OUT "$xml";
            #close (OUT);
        }
    }

    # $xml = TextpressoGeneralTasks::ReplaceSpecChar($xml);
        
    return $xmlcopy;
}

sub linkSpecialVariationsUsingPatternMatch {
    my $self = shift;
    # cis double mutant case (like zu405te33)
    my $xml = shift;
    my $lexicon_ref = shift;
    my $orig_ref = shift;

    my %already_linked = ();
    my $xmlcopy = $xml;
    while ($xml =~ /\b([a-z]{1,3}\d+)([a-z]{1,3}\d+)\b/g) {
        my ($var1, $var2) = ($1, $2);
        if ( defined( $already_linked{$var1}{$var2} ) ) {
            next;
        }
        else {
            $already_linked{$var1}{$var2} = 1;
        }
             
        $self->log->info("  variation (caught with pattern match): $var1$var2");
        
        my $url1;
        my $url2;
        $url1 = "http://www.wormbase.org/db/get?name=$var1;class=Variation" 
            if ( defined($lexicon_ref->{$var1}{"Variation"}) );
        $url2 = "http://www.wormbase.org/db/get?name=$var2;class=Variation" 
            if ( defined($lexicon_ref->{$var2}{"Variation"}) );

        if ($url1 && $url2) {
            $self->log->info("  Linking $var1$var2");
            
            my $hidden_entity = GeneralTasks::get_hidden_entity( $var1, $orig_ref );
            (my $hidden_url = $url1) =~ s/\Q$var1\E/$hidden_entity/;
            my $jsid = 1;
            foreach ($xml =~ /\b\Q$var1\E/g) {
                my $repl =  "<a href=\"$hidden_url\" id=\"$hidden_entity-$jsid\">$hidden_entity</a>"
                          . "<a href=\"javascript:removeLinkAfterConfirm('$hidden_entity-$jsid')\">"
                          . "<sup><img src=\"/gsa/img/minus.png\"/></sup>"
                          . "</a>";
                $xmlcopy =~ s/\b\Q$var1$var2\E\b/$repl$var2/;
                $jsid++;
            }

            $hidden_entity = GeneralTasks::get_hidden_entity( $var2, $orig_ref );
            ($hidden_url = $url2) =~ s/\Q$var2\E/$hidden_entity/;
            $jsid = 1;
            foreach ($xml =~ m{</a>\Q$var2\E\b}g) {
                my $repl =  "<a href=\"$hidden_url\" id=\"$hidden_entity-$jsid\">$hidden_entity</a>"
                          . "<a href=\"javascript:removeLinkAfterConfirm('$hidden_entity-$jsid')\">"
                          . "<sup><img src=\"/gsa/img/minus.png\"/></sup>"
                          . "</a>";
                $xmlcopy =~ s{</a>\Q$var2\E\b}{</a>$repl};
                $jsid++;
            }
        } 
        elsif ($url1) {
            $self->log->info("  Linking $var1");
            my $hidden_entity = GeneralTasks::get_hidden_entity( $var1, $orig_ref );
            (my $hidden_url = $url1) =~ s/\Q$var1\E/$hidden_entity/;
            my $jsid = 1;
            foreach ($xml =~ /\b\Q$var1\E/g) {
                my $repl =  "<a href=\"$hidden_url\" id=\"$hidden_entity-$jsid\">$hidden_entity</a>"
                          . "<a href=\"javascript:removeLinkAfterConfirm('$hidden_entity-$jsid')\">"
                          . "<sup><img src=\"/gsa/img/minus.png\"/></sup>"
                          . "</a>";
                $xmlcopy =~ s/\b\Q$var1$var2\E\b/$repl$var2/;
                $jsid++;
            }
        } 
        elsif ($url2) {
            $self->log->info("  Linking $var2");
            my $hidden_entity = GeneralTasks::get_hidden_entity( $var2, $orig_ref );
            (my $hidden_url = $url2) =~ s/\Q$var2\E/$hidden_entity/;
            my $jsid = 1;
            foreach ($xml =~ m{\b\Q$var1$var2\E\b}g) {
                my $repl =  "<a href=\"$hidden_url\" id=\"$hidden_entity-$jsid\">$hidden_entity</a>"
                          . "<a href=\"javascript:removeLinkAfterConfirm('$hidden_entity-$jsid')\">"
                          . "<sup><img src=\"/gsa/img/minus.png\"/></sup>"
                          . "</a>";
                $xmlcopy =~ s{\b\Q$var1$var2\E\b}{$var1$repl};
                $jsid++;
            }
        }
    }

    return $xmlcopy;
}

sub linkVariationUsingPatternMatch {
    my $xml = shift;
    my $entity_name = shift;
    my $lexicon_ref = shift;
    
    if ($entity_name =~ /([a-z]{1,3}\d+)([a-z]{1,3}\d+)/) {
	    my $part1 = $1;
    	my $part2 = $2;
	    if (defined($lexicon_ref->{$part2}{"Variation"})) { # entries like ct46ct101 need to be linked to ct46 and ct101 pages
	        my $url1 = "http://www.wormbase.org/db/get?name=$part1;class=Variation";
	        my $url2 = "http://www.wormbase.org/db/get?name=$part2;class=Variation";
	        $xml =~ s/\b($part1)($part2)\b/<a href=\"$url1\">$1<\/a><a href=\"$url2\">$2<\/a>/g;
    	} 
        else {
	        my $url = "http://www.wormbase.org/db/get?name=$part1;class=Variation";
	        $xml =~ s/\b($entity_name)\b/<a href=\"$url\">$1<\/a>/g;
    	}
    } elsif ($entity_name =~ /([a-z]{1,3}\d+)(\w*)$/) { # link entries like ad450sd to ad450 page
	    my $url = "http://www.wormbase.org/db\/get?name=$1;class=Variation";
    	$xml =~ s/\b($entity_name)\b/<a href=\"$url\">$1<\/a>/g;
    }
    
    return $xml;
}

sub removeUnwantedLinks {
    my $self = shift;
    my $xml = shift;
    my $xml_format = shift;
    
    my $ret = "";
    if ($xml_format eq FLAT_XML_ID) {
        $ret = removeUnwantedLinksFlatXml($xml);
    } elsif ($xml_format eq NLM_XML_ID) {
        $ret = removeUnwantedLinksNlmXml($xml);
    }
    
    return $ret;
}

sub removeUnwantedLinksNlmXml {
    my $xml = shift;

    $xml = GeneralTasks::removeLinksInAcknowledgments( $xml );

    # remove any links in query comments like 
    # <!-- Q1 -->
    # <!-- Q2 -->
    # etc.,
    $xml =~ s{(<!-- )<a href="http://www\.wormbase\.org\S+?" id=".+?">(.+?)</a><a href=".+?"><sup><img src="\S+?"/></sup></a>( -->)}
    {$1$2$3}g;

    my @xmls = split(/\n/, $xml);
    my $ret = "";

    for $xml (@xmls) {
        if ($xml =~ /^<contrib contrib-type="author"/) {
            # then leave the links; these are author links
        } 
        elsif (dontLinkLine($xml, NLM_XML_ID)) {
            $xml =~ s{<a href="http://www\.wormbase\.org/.+?" id=".+?">(.+?)</a><a href=".+?"><sup><img src="\S+?"/></sup></a>}{$1}g;
            $xml =~ s{<a href="http://www\.wormbase\.org/.+?">(.+?)</a>}{$1}g; # for GSP-3/4 - link to 4
        } 

        # if gene followed by :: remove link
        $xml =~ s{<a href="http://www\.wormbase\.org/db/get\?name=\S+?;class=Gene" id=".+?">(\S+?)</a><a href=".+?"><sup><img src="\S+?"/></sup></a>(</I>)?(::)}{$1$2$3}g;
#        $xml =~ s{<a href="http://www\.wormbase\.org/db/get\?name=\S+?;class=Gene" id=".+?">(\S+?)</a><a href=".+?"><sup><img src="\S+?"/></sup></a>(</italic>::)}{$1$2$3}g;
#         $xml =~ s{\<a href\="http\:\/\/www\.wormbase\.org\/db\/get\?name\=\S+?\;class\=Gene" id\=".+?"\>(\S+?)\<\/a\>\<a href\=".+?"\>\<sup\>\<img src\="\S+?"\/\>\<\/sup\>\<\/a\>(\<\/italic\>)?(\:\:)}{$1$2$3}g;
#$xml =~ s{<a href="http://www\.wormbase\.org/db/get\?name=\S+?;class=Gene" id=".+?">(\S+?)</a><a href=".+?"><sup><img src="\S+?"/></sup></a>(</italic>::)}{$1$2$3}g;

        # if gene preceded by : remove link
#        $xml =~ s{(::<I>)<a href="http://www\.wormbase\.org/db/get\?name=\S+?;class=Gene" id=".+?">(\S+?)</a><a href=".+?"><sup><img src="\S+?"/></sup></a>}{$1$2$3}g;
       $xml =~ s{(::<italic>)<a href="http://www\.wormbase\.org/db/get\?name=\S+?;class=Gene" id=".+?">(\S+?)</a><a href=".+?"><sup><img src="\S+?"/></sup></a>}{$1$2$3}g;
        $xml =~ s{(:)<a href="http://www\.wormbase\.org/db/get\?name=\S+?;class=Gene" id=".+?">(\S+?)</a><a href=".+?"><sup><img src="\S+?"/></sup></a>}{$1$2$3}g;
#        $xml =~ s{<a href=".+?" id=".+?">(\S+?)</a><a href=".+?"><sup><img src=".+?"/></sup></a></italic>\:\:}{$1}g;            
        # Unlink genes that have a suffix 'p'
        # <a href="http://www.wormbase.org/db/get?name=aex-3;class=Gene">aex-3</a><SUB>p</SUB>
        # $xml =~ s/\<a href=\"http\:\/\/www\.wormbase\.org\/db\/get\?name=\S+?\;class=Gene\"\>(\S+?)\<\/a\>(\<SUB\>p\<\/SUB\>)/$1$2/g;
        $xml =~ s{<a href="http://www\.wormbase\.org/db/get\?name=\S+?;class=Gene" id=".+?">(\S+?)</a><a href=".+?"><sup><img src="\S+?"/></sup></a>(<SUB>p</SUB>)}{$1$2}g;
        # Phenotype entity linking part to not link terms with in italics.
        $xml =~ s#(<I>)<a href="http://www\.wormbase\.org/db/get\?name=\S+?\;class=Phenotype" id=".+?">(\S+?)</a><a href=".+?"><sup><img src="\S+?"/></sup></a>(</I>)#$1$2$3#g;
#        $xml =~ s#(<italic>)<a href="http://www\.wormbase\.org/db/get\?name=\S+?\;class=Phenotype" id=".+?">(\S+?)</a><a href=".+?"><sup><img src="\S+?"/></sup></a>(</italic>)#$1$2$3#g;

        $ret .= $xml."\n";
    }
    return $ret;
}

sub removeUnwantedLinksFlatXml {
    my $xml = shift;

    my @xmls = split(/\n/, $xml);
    my $ret = "";

    for my $line (@xmls) {
        if (dontLinkLine($line, FLAT_XML_ID)) {
            $line =~ s#<a href="http://www\.wormbase\.org/.+?">(.+?)</a>#$1#g;
        } 
        elsif ($line !~ m#<Authors>.+</Authors>#) { # remove persons other than authors (in Authors tag) getting linked
            $line =~ s#<a href="http://www\.wormbase\.org/db/misc/person\?name=.+?">(.+?)</a>#$1#g;
        }

        # do not link only the gene part in transgenes. eg: do not link eor-1p or EOR-1 in eor-1p::EOR-1::GFP
        #$line =~ s/\<a href=\"http\:\/\/www\.wormbase\.org\/db\/gene\/gene\?name=\S+?\;class=Gene\"\>(\S+?)\<\/a\>(\:)/$1$2/g;
        $line =~ s/\<a href=\"http\:\/\/www\.wormbase\.org\/db\/get\?name=\S+?\;class=Gene\"\>(\S+?)\<\/a\>(\<\/I\>)?(\:\:)/$1$2$3/g;
        $line =~ s/\<a href=\"http\:\/\/www\.wormbase\.org\/db\/get\?name=\S+?\;class=Gene\"\>(\S+?)\<\/a\>(\<\/italic\>)?(\:\:)/$1$2$3/g;

        #$line =~ s/(\:)\<a href=\"http\:\/\/www\.wormbase\.org\/db\/gene\/gene\?name=\S+?\;class=Gene\"\>(\S+?)\<\/a\>/$1$2/g;
      $line =~ s/(\:)\<a href=\"http\:\/\/www\.wormbase\.org\/db\/get\?name=\S+?\;class=Gene\"\>(\S+?)\<\/a\>/$1$2/g;
      $line =~ s/(\:\:\<italic\>)\<a href=\"http\:\/\/www\.wormbase\.org\/db\/get\?name=\S+?\;class=Gene\"\>(\S+?)\<\/a\>/$1$2/g;

        # <i><a href="http://www.wormbase.org/db/gene/gene?name=eor-1;class=Gene">eor-1p</a>::<a href="http://www.wormbase.org/db/gene/gene?name=EOR-1;class=Gene">EOR-1</a>::GFP</i>
                
        # Unlink genes that have a suffix 'p'
        # <a href="http://www.wormbase.org/db/get?name=aex-3;class=Gene">aex-3</a><SUB>p</SUB>
        $line =~ s/\<a href=\"http\:\/\/www\.wormbase\.org\/db\/get\?name=\S+?\;class=Gene\"\>(\S+?)\<\/a\>(\<SUB\>p\<\/SUB\>)/$1$2/g;

        # Please fix the
        # Phenotype entity linking part to not link terms with in italics.
        # Phenotype terms should only be automatically linked if they occur
        # like "Hin" -first letter capitalized and plain text only.
        $line =~ s#(<I>)<a href="http://www\.wormbase\.org/db/get\?name=\S+?\;class=Phenotype">(\S+?)</a>(</I>)#$1$2$3#g;
#        $line =~ s#(<italic>)<a href="http://www\.wormbase\.org/db/get\?name=\S+?\;class=Phenotype">(\S+?)</a>(</italic>)#$1$2$3#g;


        $ret .= $line."\n";
    }
    return $ret;
}

sub removeXmlStuff {
    my $self = shift;
    my $line = shift;
    $line =~ s/\<.+?\>/ /g;
    $line =~ s/\&#x(\S+?);//g;
    return $line;
}

sub loadLexicon {
    my $self        = shift;

    my $lexicon        = {};
    my $sorted_entries = [];
    
    my %classes = ();
    my $file = $self->lexicon_file;
    open (IN, "<$file") or $self->log->die("Couldn't open the lexicon file at $file");
 
   $self->log->info("Loading lexicon...");
    while (my $lexicon_line = <IN>) {
        chomp($lexicon_line);
        my $entity_name;
        my $entity_id;
        my $class_name;
        my @entries = split(/\t/, $lexicon_line);
	
        if (scalar(@entries) == 3) { # like "entity_name    entity_id   class_name"
            ($entity_name, $entity_id, $class_name) = @entries;
        } 
        else { # like "entity_name  class_name" - entity_name itself is also entity_id
            ($entity_name, $class_name) = @entries;
            $entity_id = $entity_name;
        }
        $lexicon->{$entity_name}{$class_name} = $entity_id;
        push @$sorted_entries, $entity_name;
    }
    close (IN);
    
    $self->log->info("     Size of lexicon = " . scalar(keys %$lexicon));
    return ($lexicon,$sorted_entries);
}


# Not converted to OO


sub writeOutput {
    my $infile = shift;
    my $outdir = shift;
    my $linked_xml = shift;
    
    # save the linked file on server
    my $outfile = $outdir . "/" . getFileName($infile) . "_linked.xml";
    open (OUT,">$outfile") or die ("Died. could not open $outfile for writing.");
    print OUT "$linked_xml\n";
    close (OUT);
    
    # ftp the linked file to dartmouth
    use Net::FTP;
    print "FTPing outfile to dartmouth\n";
    my $ftp = Net::FTP->new("ftp1.dartmouthjournals.com", Passive=>1) or die ("Died: Could connect to dartmouth ftp server");
    $ftp->login('genetics', '22dna25') or die ("could not authenticate");
    $ftp->cwd("WormBase") or die ("could not change working dir to WormBase\n");
    my $fn = getFileName($infile)."_linked.xml";
    $ftp->put($outfile, $fn) or die ("Could not put file using FTP: $@\n");
    
    # change the file extension to HTML for easy viewing of links
    my $html_file = $outdir . "/" . getFileName($infile) . ".html";
    my @args = ("mv", $outfile, $html_file);
    system(@args) == 0 or die ("Died: could not move file in $outdir\n");
    
    # email people
}

sub getFileName {
    my $infile = shift;
    my @e = split(/\//, $infile);
    my $ret = pop @e;
    $ret =~ s/\.\S+$//;
    return($ret);
}

sub regexForXml {
    my $entry = shift;
    my @letters = split(//, $entry);
    my $regex = join ("\<?.+?\>?", @letters); # ct46gf is in XML removed stuff. ct46</I>gf is in XML
    return ($regex);
}

sub getStopWords {
    my $f = shift;
    open (IN, "<$f") or die ("could not open $f for reading!\n");
    my $s = '(';
    while (<IN>) {
        chomp;
        $s .= $_ . '|';
    }
    $s =~ s/\|$//;
    $s .= ')';
    return $s;
}

sub getPhenotypeIds {
    my $file = shift;
    open (IN, "<$file") or die ("died: no infile $file\n");
    my %hash = ();
    while (my $line = <IN>) {
        chomp($line);
        (my $name, my $id) = split(/\t/, $line);
        $hash{$name} = $id;
    }
    close IN;
    return %hash;
}

sub getPersonIds {
    my $file = shift;
    open (IN, "<$file") or die ("died: no infile $file\n");
    my %hash = ();
    while (my $line = <IN>) {
        chomp($line);
        (my $name, my $id) = split(/\t/, $line);
        $hash{$name} = $id;
    }
    close IN;
    return %hash;
}

sub get_total_number_of_links {
    my $self = shift;
}

# was: formEntityTable
sub build_entity_report {
    my ($self,$params) = @_;
   
    my $linked_xml = $self->linked_xml;
    my $wbpaper_id = $self->wormbase_paper_id;
    my $stage      = $self->stage;
    my $log_file   = $self->log_file;
    my $id         = $self->file_id;
    
    $self->log->info("Building entity report for $stage: $id");
    
    # This must be supplied.
    my $xml_format = GeneralTasks::getXmlFormat($self->input_file);
    
    # Get different docId's for the article
    # I don't have these methods yet
    my $doi         = GeneralTasks::getDoi($linked_xml, $xml_format);
    my $genetics_id = GeneralTasks::getGeneticsId($linked_xml, $xml_format);

    # TH: These previously went to entity_reports or entity_link_tables.
    #     Now, they go to output/CLIENT/ID/STAGE/ID-report.html
    my $outfile = join('/',$self->stage_directory,$self->report_file);
    open (OUT, ">$outfile") or die ("Could not open $outfile for writing: $!");
    
    # Uniquify on class, entity and link    
    my %entity_url_hash = ();
    my $total_num_links = 0;
    while ($linked_xml =~ m{<a href="(http://www\.wormbase\.org/.+?)"( id=".+?")?>(.+?)</a>}g) {
        my $url = $1;
        my $entity_name = $3;
	
#	last if $total_num_links == 10;
        if (not defined($entity_url_hash{$entity_name}{$url})) {
            $entity_url_hash{$entity_name}{$url} = 1;
        } else {
            $entity_url_hash{$entity_name}{$url}++;
        }

#	$entity_url_hash{$entity_name}{$url}++;	
        $total_num_links++;
    }
    
    # append to log file just to check if the script is run multiple times for any genetics paper
    open(LOG, ">>$log_file") or die("could not open log file $log_file for writing: $!\n"); 
    # print start time to log file
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    printf LOG "Begin time = %4d-%02d-%02d %02d:%02d:%02d\n\n",$year+1900,$mon+1,$mday,$hour,$min,$sec;
    
    # Check links
    my %hash = ();
    for my $entity (sort keys %entity_url_hash) {
        for my $link (sort {lc($a) cmp lc($b)} keys %{$entity_url_hash{$entity}}) {
            my $class = $self->get_entity_class_from_link($link);
            #my $link_status = isLivePage( $link );

            # Log requests, dunno why.
            print LOG "$entity\t$class\t$link\n";
            ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
            printf LOG "%4d-%02d-%02d %02d:%02d:%02d\n",$year+1900,$mon+1,$mday,$hour,$min,$sec;

	    my %data = ();
	    $data{link} = $link;
	    my $ua            = $self->my_user_agent;
	    my $response      = $ua->get($link);
	    my $response_code = $response->status_line;
	    my $content       = $response->content;
	    my $request_status;
            if (
		($content =~ /has no record for/i)
		|| # For missing Person, WormBase page says "has no record for Lisa L. Maduzia".
		($content =~ /No results found/i)
		|| # missing objects for other classes 
		($content =~ /not found in the database/i)  
		) { 
		$request_status = 'silent';
            } elsif ( $response_code =~ /^5\d\d/) { # Various 5xx		
		$request_status = 'server error';
	    } elsif ( $response_code =~ /404/) {
		$request_status = 'not_found';
            } else { # live
                # extract some content from the downloaded page for display on the entity table
		
		# It would be better to send direct requests to the API
		# instead of screen scraping.  -- TH. See the consume_rest_interface for example.
		
                # put the entire content in one line for easy pattern matching below
                my @lines = split(/\n/, $content);
                $content = join(" ", @lines);
		
                # Fetch the page title.
                $content =~ /<title>(.+?)<\/title>/i;
                my $title = $1;
		die $content unless $title;
		
		# Remove things that just create clutter.
                $title =~ s/\(WB.+?\)//g;
                $title =~ s/\s{2,}/ /g;
		$title =~ s/\- WormBase : Nematode Information Resource//g;
		
		$data{content}{'page title'} = $title;		
		
                # Extract contents from some fields.
		# Other entities just display the title.
                if ($class eq "Variation") {
		    
		    my $json = $self->consume_rest_interface("/rest/widget/variation/$entity/overview");
		    if ($json) {
			my $gene_id = $json->{fields}->{corresponding_gene}->{data}->[0]->{id};
			my $label   = $json->{fields}->{corresponding_gene}->{data}->[0]->{label};		       
			$data{content}{'corresponding gene'} = 
			    a({-href=>"http://www.wormbase.org/db/get?name=$gene_id;class=Gene",
			       -target => '_blank'
			      },							   
			      $label);
		    }
		} elsif ($class eq "Phenotype") {
		    $content =~ /<th.+?>\s*Primary\s+name:.+?<a.+?>(.+?)<\/a>/i;
                    my $primary_name = $1;
		    $data{content}{primary_name} = $primary_name;
#		    $hash{$class}{$entity}{"<B>Title</B>: '$title' <BR/> <B>Corresponding gene</B>: '$gene'"} = $link;
		} elsif ($class eq "GO") {
                    $content =~ m#<th.+?>\s*Term:.*?<td.*?>(.+?)</td>#i;
                    my $GO_term = $1;
#                    if ($title eq 'Gene Ontology Search') {
		    $data{content}{go_term} = $GO_term;
#		    } else {
#			$data{content} = "<B>Title</B>: '$title' <BR/> <B>Term</B>: '$GO_term'";
#		    }
		} else { }
		$request_status = 'live';
            }
	    
	    $data{request_status} = $request_status;
	    $data{response_code}  = $response_code;
	    

	    $self->log->info(join("\t",
				  '  ',
				  "Entity: $entity",
				  "Class: $class",
				  "Status: $request_status",
				  "Response: $response_code"));
	    print LOG "Status: $request_status\n";

            # OMG
            ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
            printf LOG "%4d-%02d-%02d %02d:%02d:%02d\n\n",$year+1900,$mon+1,$mday,$hour,$min,$sec;

	    # we have already uniquified on entity+url
	    # Now, if an entity has more than one data hash, 
	    # we will be able to detect that it has inadvertently
	    # been linked to two different URLs.
	    push @{$hash{$class}{$entity}},\%data;
        }
    }
    
#1. The table had sortable columns
#3. rows with errors were hilighted
#4 there was some logic that tested the page title against the desired link (or maybe made a request for a widget from the page instead of the page itself)
# You could request, say, the overview widget which should exist on every page.
# If that's succesful, the full page link will also work.
# and you could parse some of the data to see if it matches the requested object in the url
    
    # print end time to log file
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    printf LOG "End time: %4d-%02d-%02d %02d:%02d:%02d\n\n",$year+1900,$mon+1,$mday,$hour,$min,$sec;
    close(LOG);

    # Start up the report table.
    my ($title,$bgcolor,$msg);
    if ($stage eq "first pass") {
	$title = "First pass entity table for $wbpaper_id";
	$bgcolor = "Silver";
	$msg = "This is the first pass entity table.";
    } else {
	$title = "Entity table for $wbpaper_id";
	$bgcolor = '#AABBCC';
    }
    print OUT 
	header(),
	start_html(-title   => $title,
		   -bgcolor => $bgcolor);   
    print OUT
	h1($msg),
	h2("Genetics DOI: $doi"),
	h2("WB Paper ID : $wbpaper_id"),
	h3("Title : "   . GeneralTasks::getArticleTitle($linked_xml, $xml_format)),
	h3("Authors : " . GeneralTasks::getAuthors($linked_xml, $xml_format));
    
    print OUT <<END;
<p>
<b>Note</b>: <br />

The links that are flagged 'live' have a current and valid WormBase page. <br/>
The links that are flagged as <font color=\"red\">silent</font> are new entities and are not currently live
but have been forwarded to an appropriate WormBase curator. They will become live soon. <br/>
The links that are flagged as <font color=\"magenta\">read timeout</font> are the ones for which
WormBase did not return anything within 60 secs at the time the script checked the link.
Most likely these links are live, so please click on the link manually and verify. <br/>
If you have any questions or find any errors please contact Karen Yook at kyook\@caltech.edu 
</p>
END
;
    
    print OUT start_table({-border=>1});
    print OUT
	TR(
	    th('Entity class'),
	    th('Entity name'),
	    th('link'),
	    th('response code'),
	    th('response status'),	    
	    th('relevant content from URL'),
	    th('# of linked occurrences'));
    
    for my $class (sort keys %hash) {
        for my $entity (sort {lc($a) cmp lc($b)} keys %{$hash{$class}}) {
	    foreach my $data (@{$hash{$class}{$entity}}) {
		my $status = $data->{request_status};
		
		my $class_display = $class eq 'Gene' ? 'Gene/Protein' : $class;
		
		my $status_class;
                if ($status eq 'silent') {
		    $status_class = 'silent';  # red
                } elsif ($status eq "timeout") {
		    $status_class = 'timeout';  # magenta
                } elsif ($status eq "server error") {
		    $status_class = 'server-error';  # magenta
                } else { # the status itself has some content downloaded from the URL
		    $status_class = 'live';
                }
		
		my $content = join("<br />",
				   map { "<b>$_</b>: $data->{content}->{$_}" } keys %{$data->{content}});
		
		my $link = $data->{link};
		print OUT 
		    TR(
			td($class_display),
			td($entity),
			td(a({-href=>$data->{link},-target=>'_blank'},$data->{link})),
			td($data->{response_code}),
			td(span({-class=>$status_class},$status)),
			td($content),
			td($entity_url_hash{$entity}{$link}));
            }
        }
    }
    print OUT
	TR(
	    td({-colspan=>6},b('TOTAL')),
	    td(b($total_num_links)));
    print OUT end_table();
    print OUT end_html();
    close OUT;
    
    
    # This should use an actual logging system!
    $self->log->info("Entity table report for " 
		     . $self->stage
		     . " now available at:\n"       
		     . $self->stage_directory . '/' . $self->report_file);
}

sub get_entity_class_from_link {
    my ($self,$link) = @_;
    
    if ( ($link =~ /(Gene)/) 
	 || ($link =~ /(Strain)/)
	 || ($link =~ /(Clone)/) 
	 || ($link =~ /(Transgene)/) 
	 || ($link =~ /(Rearrangement)/) 
	 || ($link =~ /(Sequence)/)
	 || ($link =~ /(Phenotype)/) ) {
        return $1;
    } elsif ($link =~ /Variation/i) {
        return "Variation";
#    } elsif ($link =~ /anatomy/i) {
#        return "Anatomy";
    } elsif ($link =~ /person/i) {
        return "Person";
    } elsif ($link =~ /GO_term/i) {
        return "GO";
    }    
    $self->log->die("The link $link does not have a valid entity class");
}



# not OO
sub getAuthorObjects {
    my $contents = shift;
#    my $af_page = "http://tazendra.caltech.edu/~postgres/cgi-bin/journal/journal_all.cgi?action=Show+Data&type=textpresso";
    my $af_page = "http://tazendra.caltech.edu/~postgres/cgi-bin/author_fp_display.cgi?action=Show+Data&type=textpresso"; 
    # $contents = TextpressoGeneralTasks::InverseReplaceSpecChar($contents);
    $contents =~ /\<doi\>(.+)\<\/doi\>/; # <doi>10.1534/genetics.110.115188</doi>
    my $doi = "doi".$1;

    my $author_form_contents = TextpressoGeneralTasks::getwebpage($af_page);
    my @lines = split(/\n/, $author_form_contents);

    my $wbpaper_id = 0;
    my %data_entries = ();
    
    for (my $i = 0; $i < @lines; $i++) {
        if ($lines[$i] eq "\<tr\>") {
            my $doi_in_form = $lines[$i+1];
            $doi_in_form =~ s/\<.+?\>//g;
            if ($doi_in_form eq $doi) {
                $wbpaper_id = $lines[$i+2];
                $wbpaper_id =~ s/\<.+?\>//g;

                my $data_line = $lines[$i+4];
                $data_line =~ s/\<.+?\>//g;

                # remove invalid data i.e. anything after ~~
                $data_line =~ s/~~.+$//;
                # remove stuff inside [ ]
                $data_line =~ s/\[.+?\]//g;
                # assuming author data is comma-separated
                my @entries = split(/\,/, $data_line);

                for my $e (@entries) {
                    $e =~ s/^\s+//;
                    $data_entries{$e} = 1;
                }
            }
        }
    }
    
    return %data_entries;
}


# this sub-routine may need clean-up later if more curators are added
# or if the curator name changes!
sub getResponsibleCurator {
    # for GO evaluation only
    # return "everyone";
    
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
            = localtime(time); # $mon = 0 for Jan

#    my @curator_emails = @{(WormbaseLinkGlobals::CURATOR_EMAILS)};
    my @curator_emails = read_file(Specs::EMAIL_DIR . 'curators.txt');

    # round robin on 3 curators depending on month
    my $responsible_curator_email = $curator_emails[ $mon % 3 ];
    my ($user_name, $domain_name) = split(/\@/, $responsible_curator_email);

    return $user_name;
}

sub replaceAnchorTagsInLinkedXml {
    my $linkedxmlfile = shift;
    
    my $output = "";
    open(IN, "<$linkedxmlfile") or die("died: could not open $linkedxmlfile for reading\n");
    while (my $line = <IN>) {
        if ($line =~ /^<contrib contrib-type="author"/) { # author name links
            $line =~ s/<name><surname><a href="(http:\/\/www\.wormbase\.org.+?)">(.+?)<\/a><\/surname><given-names><a href="http:\/\/www\.wormbase\.org\/.+?">(.+?)<\/a><\/given-names><\/name>/<name><surname>$2<\/surname><given-names>$3<\/given-names><\/name><ext-link ext-link-type="uri" xlink:href="$1"\/>/g;
        }
        else {
            $line =~ s/<a href="(http:\/\/www\.wormbase\.org\/.+?)">(.+?)<\/a>/<ext-link ext-link-type="uri" xlink:href="$1">$2<\/ext-link>/g;
        }
        
        $output .= $line;
    }
    close(IN);
    
    # output to same file
    open(OUT, ">$linkedxmlfile") or die("died: could not open $linkedxmlfile for writing.\n");
    print OUT $output;
    close(OUT);
    
    return;
}

sub isLivePage {
    my $link = shift;
    
    my $contents = get_web_page($link);
    print "$contents\n";
    
    if ( ($contents =~ /has no record for/i) || # For missing Person, WormBase page says "has no record for Lisa L. Maduzia".
         ($contents =~ /No results found/i)  || # missing objects for other classes 
         ($contents =~ /not found in the database/i)  ) { 
        return 0;
    } elsif ( $contents =~ /500 read timeout/i) {
        return -1;
    } else {
        return 1;
    }
}



sub getReceivers {
    my @receivers = ();
    for my $rec ( @{(WormbaseLinkGlobals::CURATOR_EMAILS)} ) {
        push @receivers, $rec;
    }
    
    # keep the sender informed about the emails
    push @receivers, getSender();
    
    return @receivers;
}

sub get_entity_class {
# if there are two entity classes and one of them is 'GO'
    # return the other class
    my @classes = @_;
    
    if (@classes > 1) { # multiple classes have this term
        for my $class (@classes) {
            return $class if ($class ne "GO");
        }
    } 
    else {
        return $classes[0];
    }
}

sub get_matched_entity_id {
    # id is required bcos multiple terms map to same GO id.
    my $url = shift;
    my $entity_of_ref = shift;
    my $entity_name = shift;
    
    my $id = 0;
    if (! defined $entity_of_ref->{$url}) {
        $id = 1;
    }
    else {
        my @ids = keys %{ $entity_of_ref->{$url} };
        $id = scalar(@ids) + 1;
    }
    
    $entity_of_ref->{$url}{$id} = $entity_name;
    print "entity = '$entity_name', url = '$url', id = '$id'\n";
    
    return $id;
}

sub original_txt_is_preserved {
    my $original = shift;
    my $linked   = shift;
    my $gsa_id   = shift;
    my $developer_emails;
    $developer_emails = read_file(Specs::EMAIL_DIR . '/developers.txt');
    
    # delete all links to entities
    $linked =~ s{<a href="\S+?" id=".+?">(.+?)</a><a href=".+?"><sup><img \S+?/></sup></a>}
                {$1}g;

    # special case for WB - delete author links
    $linked =~ s{<a href="http://www\.wormbase\.org/\S+?">(.+?)</a>}
                {$1}g;

    my @orig_lines   = split /\n/, $original;
    my @linked_lines = split /\n/, $linked;

    for (my $i=0; $i<@orig_lines; $i++) {
        if ($orig_lines[$i] ne $linked_lines[$i]) {
            print   "FATAL ERROR in linking. Text changed.\n\n" 
                  . "Incoming line:\n$orig_lines[$i]\n\n" 
                  . "Linked line:\n$linked_lines[$i]\n";

            # email the developer with the error
#            mailer( WormbaseLinkGlobals::DEVELOPER_EMAIL,
#                    WormbaseLinkGlobals::DEVELOPER_EMAIL,
            GeneralTasks::mailer( $developer_emails,
                    $developer_emails,
                    "Fatal error in WB GSA file $gsa_id (Text changed during linking)",
                    "Original line:\n$orig_lines[$i]\n\n"
                    . "Linked line:\n$linked_lines[$i]\n" 
                  );

            return 0;
        }
    }

    return 1;
}

sub consume_rest_interface {
    my $self = shift;
    my $url  = shift;
    my $ua = LWP::UserAgent->new();
    $ua->agent("GSA Markup Pipeline/1.0");
    $ua->default_header('Content-type' => 'application/json');

    my $link = "http://api.wormbase.org/$url";
    my $response      = $ua->get($link);
    my $response_code = $response->status_line;
    my $json          = $response->content;       
    if ($response_code eq "200 OK") {
	my $decoded_json = decode_json( $json );
	return $decoded_json;
    } else {
	return undef;
    }
}

1;
