########################################
# 040.translate_hand -- translate using handcrafted Babel & components
########################################
use t::lib;
use t::runtests;
use t::util;
use Test::More;
use Getopt::Long;
use strict;

# if --developer set, run full test suite. else just a short version
our %OPTIONS;
Getopt::Long::Configure('pass_through'); # leave unrecognized options in @ARGV
GetOptions (\%OPTIONS,qw(developer translate count history validate));

my @tests=map {"translate_hand.$_.t"} 
  qw(000.sanity 010.main 020.none 030.all 040.scalar 090.big_in);
my @options=qw(translate count history validate);
my @files;

unless ($OPTIONS{developer}) {
  # run each test with each single option
  @files=map {my $option=$_; map {my $test=$_; "$test --$option"} @tests} @options;
} else {
  # for now, just add --developer. someday, there will be option combos
  @files=map {my $option=$_; map {my $test=$_; "$test --$option --developer"} @tests} @options;
}
my $ok=runtests {testcode=>1,details=>1,exact=>1},@files;

ok($ok,script);
done_testing();
