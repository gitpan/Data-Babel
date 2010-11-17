use strict;
use warnings;
use Module::Build;
use DBI;

use lib qw(t);
use t::Build;			# my Module::Build subclass
my $class='t::Build';
# TODO: database name should be configurable
# CAUTION: $test_db duplicated in t/babelUtil.pm
our $test_db='test';

my $builder = $class->new
  (module_name         => 'Data::Babel',
   license             => 'perl',
   dist_author         => q{Nat Goodman <natg@shore.net>},
   dist_version_from   => 'lib/Data/Babel.pm',
   configure_requires=>{'DBI' => 1.604,
		       },
   build_requires =>   {'Carp' => 0,
			'Class::AutoClass' => 1.53,
			'Config' => 0,
			'Cwd' => 3.26,
			'DBI' => 1.604,
			'Exporter' => 5.58,
			'File::Basename' => 0,
			'File::Spec' => 3.26,
			'File::Spec::Functions' => 3.26,
			'FindBin' => 0,
			'Getopt::Long' => 2.13,
			'Graph' => 0.91,
			'Hash::AutoHash::Args' => 1.11,
			'List::MoreUtils' => 0.09,
			'List::Util' => 1.14,
			'Scalar::Util' => 1.01,
			'Storable' => 2.16,
			'TAP::Harness' => 3.12,
			'Test::Deep' =>  0.098,
			'Test::More' => 0.88,
			'Text::Abbrev' => 1.01,
		       },
   requires =>         {'Carp' => 0,
			'Class::AutoClass' => 1.53,
			'Class::AutoDB' => 1.20,
			'Config::IniFiles' => 2.57,
			'DBI' => 1.604,
			'File::Basename' => 0,
			'File::Spec' => 3.26,
			'Graph' => 0.91,
			'Hash::AutoHash' => 1.12,
			'Hash::AutoHash::Args' => 1.11,
			'List::MoreUtils' => 0.09,
			'Template' => 2.20,
		       },
   create_makefile_pl => 'small',
   extra_compiler_flags => ['-DUSE_PPPORT_H'],
   use_tap_harness => 1,			  
   test_files => 't/babel.*.t',
  );

# not possible to run tests unless MySQL available on 'localhost', and 
#   current user has enough privileges to do everything we need. 
# the experts recommend checking such requirements here (in Build.PL).
#   if tests cannot proceed, do not create Build and exit(0).
#   automated CPAN testers will report this as status UNKNOWN 
#   in this case, the test report will also include anything we print

my $ok=1;

my $mysql_errstr=chk_mysql() and $ok=0;
print <<EOS
These tests require that DBD::mysql version 4.007 or higher be
installed, that MySQL be running on 'localhost', that the user
running the tests can access MySQL without a password, and with these
credentials, has sufficient privileges to (1) create a 'test'
database, (2) create, alter, and drop tables in the 'test' database,
and (3) run queries and updates on the database.

When verifying these capabilities, the test driver got the following
error message:

$mysql_errstr
EOS
  if $mysql_errstr;

exit(0) unless $ok;		# do not create Build script unless tests can run

$builder->create_build_script();

# check whether MySQl test database is accessible
# return error string if not
sub chk_mysql {
  # make sure DBD::mysql is available. doesn't work to put in prereqs because
  #  if not present, install tries to install 'DBD' which does not exist
  # eval {use DBD::mysql 4.007};
  eval "use DBD::mysql 4.007";
  return $@ if $@;

  # make sure we can talk to MySQL
  my $dbh;
  eval
    {$dbh=DBI->connect("dbi:mysql:",undef,undef,
		       {AutoCommit=>1, ChopBlanks=>1, PrintError=>0, PrintWarn=>0, Warn=>0,})};
  return $@ if $@;
  return $DBI::errstr unless $dbh;

  # try to create database if necessary, then use it
  # don't worry about create-errors: may be able to use even if can't create
  $dbh->do(qq(CREATE DATABASE IF NOT EXISTS $test_db));
  $dbh->do(qq(USE $test_db)) or return $dbh->errstr;

  # make sure we can do all necessary operations
  # create, alter, drop tables. insert, select, replace, update, select, delete
  $dbh->do(qq(CREATE TABLE IF NOT EXISTS test(xxx INT))) or return $dbh->errstr;
  $dbh->do(qq(ALTER TABLE test ADD COLUMN yyy INT)) or return $dbh->errstr;
  # do drop at end, since we need table here
  $dbh->do(qq(INSERT INTO test(xxx) VALUES(123))) or return $dbh->errstr;
  $dbh->do(qq(SELECT * FROM test)) or return $dbh->errstr;
  $dbh->do(qq(REPLACE INTO test(xxx) VALUES(456))) or return $dbh->errstr;
  $dbh->do(qq(UPDATE test SET yyy=789 WHERE xxx=123)) or return $dbh->errstr;
  $dbh->do(qq(DELETE FROM test WHERE xxx=123)) or return $dbh->errstr;
  $dbh->do(qq(DROP TABLE IF EXISTS test)) or return $dbh->errstr;
  # since we made it here, we can do everything!
  undef;
}
