#!perl
use strict;
use Test::More tests => 13;
# make sure all the necesary modules exist
BEGIN {
    use_ok( 'Data::Babel' );
    use_ok( 'Data::Babel::Base' );
    use_ok( 'Data::Babel::Config' );
    use_ok( 'Data::Babel::IdType' );
    use_ok( 'Data::Babel::Master' );
    use_ok( 'Data::Babel::MapTable' );
    use_ok( 'Data::Babel::HAH_MultiValued' );
    use_ok( 'Data::Babel::PrefixMatcher' );
    for my $subclass (qw(BinarySearchList BinarySearchTree Exact PrefixHash Trie)) {
      use_ok( "Data::Babel::PrefixMatcher::$subclass" );
    }
  }
diag( "Testing Data::Babel $Data::Babel::VERSION, Perl $], $^X" );
done_testing();
