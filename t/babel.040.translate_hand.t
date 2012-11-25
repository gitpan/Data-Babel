########################################
# 040.translate_hand -- translate using handcrafted Babel & components
########################################
use t::lib;
use t::runtests;
use t::util;
use Carp;
use Getopt::Long;
use Set::Scalar;
use Test::More;
use Text::Abbrev;
use strict;

our %OPTIONS;
Getopt::Long::Configure('pass_through'); # leave unrecognized options in @ARGV
GetOptions (\%OPTIONS,qw(user_type=s suite:s));
our %user_type=abbrev qw(installer developer);
our %suite=abbrev qw(short full);
$OPTIONS{user_type}='installer' unless defined $OPTIONS{user_type};
$OPTIONS{suite}='short' unless defined $OPTIONS{suite};
my $user_type=$user_type{$OPTIONS{user_type}} ||
  confess "Invalid user_type option $OPTIONS{user_type}";
my $suite=$suite{$OPTIONS{suite}} || confess "Invalid suite option $OPTIONS{suite}";

my $subtestdir=subtestdir;
opendir(DIR,$subtestdir) or confess "Cannot read subtest directory $subtestdir: $!";
my @testfiles=sort grep /^[^.].*\.t$/,readdir DIR;
my $startup=shift @testfiles;
@testfiles=grep /main/,@testfiles if $suite eq 'short';
closedir DIR;
# my @extras=(undef,qw(history validate));
my @extras=new Set::Scalar(qw(history validate))->power_set->members;
@extras=sort {$a->size <=> $b->size} @extras;
my @ops=qw(translate count);

my @tests;
for my $extra (@extras) {
  my $test=$startup;
  $extra=join(' ',map {"--$_"} $extra->members);
  $test.=" --user_type $user_type" unless $user_type eq 'installer';
  $test.=" $extra" if length $extra;
  push(@tests,$test);
  for my $op (@ops) {
    push(@tests,
	 map {my $test="$_ --op $op";
	      $test.=" --user_type $user_type" unless $user_type eq 'installer';
	      $test.=" $extra" if length $extra;
	      $test}
	 @testfiles);
  }}

my $ok=runtests {details=>1,nested=>1,exact=>1,testdir=>scriptbasename},@tests;
ok($ok,script);
done_testing();
