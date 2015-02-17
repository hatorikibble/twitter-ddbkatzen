#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Twitter::DdbKatzen' ) || print "Bail out!\n";
}

diag( "Testing Twitter::DdbKatzen $Twitter::DdbKatzen::VERSION, Perl $], $^X" );
