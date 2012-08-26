use t::lib;
use t::runtests;
use t::util;
use Test::More;
use Getopt::Long;
use strict;

# if --developer set, run full test suite. else just a short version
our %OPTIONS;
Getopt::Long::Configure('pass_through'); # leave unrecognized options in @ARGV
GetOptions (\%OPTIONS,qw(developer));

# 010.star, 020.chain are obsolete -- 030.tree covers them. 
#   but, since they work, why not include them...
my @files;

unless ($OPTIONS{developer}) {
  @files=
    ('translate.010.star.t staggered 4',
     'translate.010.star.t binary 4',
     'translate.020.chain.t staggered 4',
     'translate.020.chain.t binary 4',);
} else {
  @files=
    ('translate.010.star.t staggered',
     'translate.010.star.t binary',
     'translate.020.chain.t staggered',
     'translate.020.chain.t binary',
     'translate.030.tree.t staggered chainlike 2 7',
     'translate.030.tree.t staggered starlike 2 7',
     'translate.030.tree.t binary chainlike 2 7',
     'translate.030.tree.t binary starlike 2 7',
     'translate.030.tree.t staggered chainlike 1 6',
     'translate.030.tree.t binary chainlike 1 6',
     'translate.030.tree.t staggered chainlike 6 6',
     'translate.030.tree.t staggered starlike 6 6',
     'translate.030.tree.t binary chainlike 6 6',
     'translate.030.tree.t binary starlike 6 6',
     'translate.030.tree.t staggered chainlike 3 6',
     'translate.030.tree.t staggered starlike 3 6',
     'translate.030.tree.t binary chainlike 3 6',
     'translate.030.tree.t binary starlike 3 6',
     'translate.030.tree.t staggered chainlike 3 8 1',
     'translate.030.tree.t staggered starlike 3 8 1',
     'translate.030.tree.t binary chainlike 3 8 1',
     'translate.030.tree.t binary starlike 3 8 1',
     'translate.030.tree.t staggered chainlike 4 8 1',
     'translate.030.tree.t staggered starlike 4 8 1',
     'translate.030.tree.t binary chainlike 4 8 1',
     'translate.030.tree.t binary starlike 4 8 1',
    );
}
my $ok=runtests {testcode=>1,details=>1,exact=>1},@files;

ok($ok,script);
done_testing();
