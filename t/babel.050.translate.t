use t::lib;
use t::runtests;
use t::util;
use Carp;
use Getopt::Long;
use Test::More;
use Text::Abbrev;
use strict;

# NOT YET PORTED TO NEW 050.star TESTS

# if --developer set, run full test suite. else just a short version
our %OPTIONS;
Getopt::Long::Configure('pass_through'); # leave unrecognized options in @ARGV
GetOptions (\%OPTIONS,qw(user_type=s));
our %user_type=abbrev qw(installer developer);
$OPTIONS{user_type}='installer' unless defined $OPTIONS{user_type};
my $user_type=$user_type{$OPTIONS{user_type}} ||
  confess "Invalid user_type option $OPTIONS{user_type}";

my $subtestdir=subtestdir;
opendir(DIR,$subtestdir) or confess "Cannot read subtest directory $subtestdir: $!";
my @mainfiles=sort grep /^[^.].*\.t$/,readdir DIR;
closedir DIR;
my @ops=qw(translate count);
my @db_types=$user_type eq 'developer'? qw(binary staggered basecalc): qw(binary);
my @graph_types=$user_type eq 'developer'? qw(star chain tree): qw(star);

my @testfiles;
for my $op (@ops) {
  for my $db_type (@db_types) {
    for my $graph_type (@graph_types) {
      push(@testfiles,
	   map {my $test="$_ --op $op";
		$test.=" --db_type $db_type --graph_type $graph_type --user_type $user_type" unless $user_type eq 'installer';
		$test}
	   @mainfiles);
    }}}
my $ok=runtests {details=>1,nested=>1,testdir=>scriptbasename},@testfiles;
ok($ok,script);
done_testing();
