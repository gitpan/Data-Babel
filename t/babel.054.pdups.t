use t::lib;
use t::runtests;
use t::util;
use Carp;
use Getopt::Long;
use Test::More;
use Text::Abbrev;
use strict;

# if --developer set, run longer versions of tests
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
my @ops=qw(translate count);
my @graph_types=$user_type eq 'developer'? qw(star chain tree): qw(star);

my @tests;
for my $graph_type (@graph_types) {
  my $test=$startup;
  $test.=" --graph_type $graph_type --user_type $user_type" unless $user_type eq 'installer';
  push(@tests,$test);
  for my $test (@testfiles) {
    push(@tests,"$test -op translate","$test -op translate --validate","$test -op count");
  }}

my $ok=runtests {details=>1,nested=>1,exact=>1,testdir=>scriptbasename},@tests;
ok($ok,script);
done_testing();
