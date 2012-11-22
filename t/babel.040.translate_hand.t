########################################
# 040.translate_hand -- translate using handcrafted Babel & components
########################################
use t::lib;
use t::runtests;
use t::util;
use Carp;
use Test::More;
use Getopt::Long;
use Text::Abbrev;
use strict;

our %OPTIONS;
Getopt::Long::Configure('pass_through'); # leave unrecognized options in @ARGV
GetOptions (\%OPTIONS,qw(user_type=s));
our %user_type=abbrev qw(installer developer);
$OPTIONS{user_type}='installer' unless defined $OPTIONS{user_type};
my $user_type=$user_type{$OPTIONS{user_type}} ||
  confess "Invalid user_type option $OPTIONS{user_type}";

my $subtestdir=subtestdir;
opendir(DIR,$subtestdir) or confess "Cannot read subtest directory $subtestdir: $!";
my @testfiles=sort grep /^[^.].*\.t$/,readdir DIR;
my $startup=shift @testfiles;
closedir DIR;
# my @extras=(undef,qw(history validate));
my @extras=(undef,qw(history));
my @ops=qw(translate count);

my @tests;
for my $extra (@extras) {
  my $test=$startup;
  $test.=" --user_type $user_type" unless $user_type eq 'installer';
  $test.=" --$extra" if defined $extra;
  push(@tests,$test);
  for my $op (@ops) {
    push(@tests,
	 map {my $test="$_ --op $op";
	      $test.=" --user_type $user_type" unless $user_type eq 'installer';
	      $test.=" --$extra" if defined $extra;
	      $test}
	 @testfiles);
  }}

my $ok=runtests {details=>1,nested=>1,testdir=>scriptbasename},@tests;
ok($ok,script);
done_testing();
