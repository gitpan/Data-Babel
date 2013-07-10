# adapted from babel.040.translate_hand
package pdups_hand;
use t::util;
use t::utilBabel;
use Carp;
use File::Spec;
use Getopt::Long;
use Hash::AutoHash;
use List::Util qw(min);
use Set::Scalar;
use Test::More;
use Text::Abbrev;
use Class::AutoDB;
use Data::Babel;
use strict;
our @ISA=qw(Exporter);

our @EXPORT=qw($OPTIONS %OPTIONS @OPTIONS $OP $autodb $babel $dbh 
	       @regular_idtypes @multi_idtypes @history_columns @idtypes @ids
	       init make_ids make_invalid_ids empty_result);
our($OPTIONS,%OPTIONS,@OPTIONS,$OP,$autodb,$babel,$dbh,
    @regular_idtypes,@multi_idtypes,@history_columns,@idtypes,@ids);
@regular_idtypes=qw(type_001 type_002 type_003 type_004);
@multi_idtypes=qw(type_multi_001 type_multi_003);
@idtypes=(@regular_idtypes,@multi_idtypes);
@history_columns=qw(_X_type_001 _X_type_002);
@ids=qw(000 001 010 011 100 101 110 111);

@OPTIONS=qw(op=s history validate);
our %op=abbrev qw(translate count);
our %user_type=abbrev qw(installer developer);
# for some options, defaults depend on user_type
our %DEFAULTS=(op=>'translate');

sub init {
  my $setup=shift @_;
  $OPTIONS=get_options();
  unless ($setup) {
    $autodb=new Class::AutoDB(database=>'test'); 
    isa_ok($autodb,'Class::AutoDB','sanity test - $autodb');
    # expect 'old' to return the babel
    $babel=old Data::Babel(name=>'test',autodb=>$autodb);
    isa_ok($babel,'Data::Babel','sanity test - old Babel returned Babel object');
  } else {			# setup new database
    $autodb=new Class::AutoDB(database=>'test',create=>1); 
    isa_ok($autodb,'Class::AutoDB','sanity test - $autodb');
    cleanup_db($autodb);		# cleanup database from previous test
    Data::Babel->autodb($autodb);
    # rest of setup done by test
  }
  $dbh=$autodb->dbh;
}
# returns Hash::AutoHash
sub get_options {
  %OPTIONS=%DEFAULTS;
  GetOptions(\%OPTIONS,@OPTIONS);
  # expand abbreviations
  for my $option (qw(op user_type)) {
    next unless defined $OPTIONS{$option};
    my %abbrev=eval "\%$option";
    $OPTIONS{$option}=$abbrev{$OPTIONS{$option}} or confess "illegal value for option $option";
  }
  $OP=$OPTIONS{op};
  $OPTIONS=new Hash::AutoHash %OPTIONS;
}
# convert idtype & id indexes to ids. if no indexes, convert all ids
sub make_ids {
  my $idtype=shift;
  my @ids=@_ || '111';
  my $id_prefix=($OPTIONS->history && grep {$idtype eq $_} qw(type_001 type_002))? 
    "${idtype}/x_": "${idtype}/a_";
  @_? map {"${id_prefix}$_"} @ids[@_]: map {"${id_prefix}$_"} @ids;
}
sub make_invalid_ids {
  my $idtype=shift;
  my $num=@_? shift: 1;
  my $id_prefix=($OPTIONS->history && grep {$idtype eq $_} qw(type_001 type_002))? 
    "${idtype}/x_": "${idtype}/a_";
  map {"${id_prefix}invalid_".sprintf('%03i',$_)} 1..$num;
}
# result can be table or count
sub empty_result {
  my $result=shift;
  ref $result? scalar @$result: $result;
}
1;
