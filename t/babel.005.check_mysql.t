# check whether MySQl test database is accessible
# use TAP version 13 support for pragmas to communicate results to TAP::Harness
# if MySQL not accessible, no further tests will run, but results reported as PASS
use strict;
use Test::More;

# TODO: database name should be configurable
# CAUTION: $test_db duplicated in t/babelUtil.pm
my $test_db='test';
my $mysql_version=4.022;

print "TAP version 13\n";
my $mysql_errstr=check_mysql();
pass('check_mysql ran');
if ($mysql_errstr) {
  my $diag= <<EOS


These tests require that DBD::mysql version $mysql_version or higher be
installed, that MySQL be running on 'localhost', that the user running
the tests can access MySQL without a password, and with these
credentials, has sufficient privileges to (1) create a 'test'
database, (2) create, alter, and drop tables in the 'test' database,
(3) create and drop views, and (4) run queries and updates on the
database.

When verifying these capabilities, the test driver got the following
error message:

$mysql_errstr

EOS
    ;
  diag($diag);
  print "pragma +stop_testing\n";
}
done_testing();

# check whether MySQl test database is accessible
# return error string if not
sub check_mysql {
  # make sure DBD::mysql is available. doesn't work to put in prereqs because
  #  if not present, install tries to install 'DBD' which does not exist
  # eval {use DBD::mysql 4.007};
  eval "use DBD::mysql $mysql_version";
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
  # NG 10-11-19: ops on views needed for Babel, not AutoDB
  # NG 10-11-19: DROP tables and views if they exist
  $dbh->do(qq(DROP TABLE IF EXISTS test_table)) or return $dbh->errstr;
  $dbh->do(qq(DROP VIEW IF EXISTS test_table)) or return $dbh->errstr;
  $dbh->do(qq(DROP TABLE IF EXISTS test_view)) or return $dbh->errstr;
  $dbh->do(qq(DROP VIEW IF EXISTS test_view)) or return $dbh->errstr;

  $dbh->do(qq(CREATE TABLE test_table(xxx INT))) or return $dbh->errstr;
  $dbh->do(qq(ALTER TABLE test_table ADD COLUMN yyy INT)) or return $dbh->errstr;
  $dbh->do(qq(CREATE VIEW test_view AS SELECT * from test_table)) or return $dbh->errstr;
  # do drop at end, since we need table here
  $dbh->do(qq(INSERT INTO test_table(xxx) VALUES(123))) or return $dbh->errstr;
  $dbh->do(qq(SELECT * FROM test_table)) or return $dbh->errstr;
  $dbh->do(qq(SELECT * FROM test_view)) or return $dbh->errstr;
  $dbh->do(qq(REPLACE INTO test_table(xxx) VALUES(456))) or return $dbh->errstr;
  $dbh->do(qq(UPDATE test_table SET yyy=789 WHERE xxx=123)) or return $dbh->errstr;
  $dbh->do(qq(DELETE FROM test_table WHERE xxx=123)) or return $dbh->errstr;
  $dbh->do(qq(DROP VIEW IF EXISTS test_view)) or return $dbh->errstr;
  $dbh->do(qq(DROP TABLE IF EXISTS test_table)) or return $dbh->errstr;
  # since we made it here, we can do everything!
  undef;
}
