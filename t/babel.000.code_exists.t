#!perl
use strict;
use Test::More tests => 6;
# make sure all the necesary modules exist
BEGIN {
    use_ok( 'Data::Babel' );
    use_ok( 'Data::Babel::Base' );
    use_ok( 'Data::Babel::Config' );
    use_ok( 'Data::Babel::IdType' );
    use_ok( 'Data::Babel::Master' );
    use_ok( 'Data::Babel::MapTable' );
}
diag( "Testing Data::Babel $Data::Babel::VERSION, Perl $], $^X" );
done_testing();
