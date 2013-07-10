########################################
# 044.translate_hand_pdups -- translate using handcrafted Babel & components
#   constructed to generate pseudo-duplicates
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
GetOptions (\%OPTIONS,qw(bundle:s));
our %bundle=abbrev qw(install full);
$OPTIONS{bundle}='install' unless defined $OPTIONS{bundle};
my $bundle=$bundle{$OPTIONS{bundle}} || confess "Invalid bundle option $OPTIONS{bundle}";

my $subtestdir=subtestdir;
opendir(DIR,$subtestdir) or confess "Cannot read subtest directory $subtestdir: $!";
my @testfiles=sort grep /^[^.].*\.t$/,readdir DIR;
closedir DIR;

my @tests;
if ($bundle eq 'install') {
  # run each test once with default parameters
  @tests=@testfiles;
}
# TODO: implement other bundles
# while(@testfiles) {
#   my($startup,$basics,$main)=splice(@testfiles,0,3);
#   for my $history (0,1) {
#     my $test=$startup;
#     $test.=' --history' if $history;
#     push(@tests,$test);
#     for my $op (qw(translate count)) {
#       my $test=$basics;
#       $test.=' --history' if $history;
#       $test.=" --op $op";
#       push(@tests,$test);
#       for my $validate (0,1) {
# 	my $test=$main;
# 	$test.=' --history' if $history;
# 	$test.=" --op $op";
# 	$test.=' --validate' if $validate;
# 	push(@tests,$test);
#       }}}}
my $ok=runtests {details=>1,nested=>1,exact=>1,testdir=>scriptbasename},@tests;
ok($ok,script);
done_testing();
