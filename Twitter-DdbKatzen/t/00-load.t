#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Twitter::EuropeanaBot' ) || print "Bail out!\n";
}

diag( "Testing Twitter::EuropeanaBot $Twitter::EuropeanaBot::VERSION, Perl $], $^X" );
