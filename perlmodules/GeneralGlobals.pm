package GeneralGlobals;

use strict;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(BASE_URL FLAT_XML_ID NLM_XML_ID);

sub get_domain_name {
    use Net::Domain qw(hostfqdn);
    return hostfqdn;
}

use constant BASE_URL => 'http://' . get_domain_name();

use constant FLAT_XML_ID => "flat";
use constant NLM_XML_ID  => "nlm";

1;
