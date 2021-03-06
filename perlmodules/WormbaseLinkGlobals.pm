package WormbaseLinkGlobals;

use strict;
require Exporter;
our @ISA = qw(Exporter);
#our @EXPORT = qw(SY_ALLELE_SUFFIXES LEFT_DELIMITERS RIGHT_DELIMITERS DEVELOPER_EMAIL CURATOR_EMAILS FINAL_EMAILS);
our @EXPORT = qw(SY_ALLELE_SUFFIXES DEVELOPER_EMAIL CURATOR_EMAILS FINAL_EMAILS);

use constant SY_ALLELE_SUFFIXES => ['ts', 'sd', 'gf', 'cs', 'lf', 'mx']; # these were the ones given by Tim Schedl

# tight coupling below - bad programming practice!
# these delimiters require that ReplaceSpecChar is called before linking!

#use constant LEFT_DELIMITERS    => ' |\_|\-|^|\n'; # space, hyphen are usual delimiters; 
                                                    # underscore bcos of TextpressoGeneralTasks::ReplaceSpecChar

#use constant RIGHT_DELIMITERS   => ' |\_|\-|$|\n'; # stuff like periods are all replaced with _PRD_ by 
                                                    # TextpressoGeneralTasks::ReplaceSpecChar

# also recall that data objects in GSA articles are always inside some tags, so an object will not start
# at the beginning of a line or won't end a line. Not the case with plain text articles!
# Having extra delimiters which will handle text files properly does not hurt XML files though!

# NOTE!
# The actual EMAIL addresses are contained in conf/emails. Odd.

# the developer is the sender
use constant DEVELOPER_EMAIL => '';

# keep developer in the loop
use constant CURATOR_EMAILS  => [ ];

# ppl who need to be notifed after everything is done
use constant FINAL_EMAILS    => [ ]; 

1;
