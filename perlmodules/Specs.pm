package Specs;
use strict;
use FindBin qw/$Bin/;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(HTML_DIR INCOMING_XML_DIR RERUN_DIR INCOMING_XML_DIR EMAIL_DIR);

use constant DONE_DIR => '/home/arunr/gsa/worm/done/';
use constant HTML_DIR => '/home/arunr/gsa/worm/html/';

use constant RERUN_DIR        => '/home/arunr/gsa/worm/rerun_linking/';
use constant INCOMING_XML_DIR => '/home/arunr/gsa/worm/incoming_xml/';
use constant EMAIL_DIR => "$Bin/../conf/emails";
