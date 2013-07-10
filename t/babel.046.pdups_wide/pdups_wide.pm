# adapted from babel.040.translate_hand
package pdups_wide;
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
	       @regular_idtypes @leaf_idtypes @xyz_idtypes @idtypes @ids
	       init make_ids make_invalid_ids empty_result);
our($OPTIONS,%OPTIONS,@OPTIONS,$OP,$autodb,$babel,$dbh,
    @regular_idtypes,@leaf_idtypes,@xyz_idtypes,@idtypes,@ids);
@regular_idtypes=qw(type_001 type_002 type_003);
@leaf_idtypes=qw(type_leaf_001 type_leaf_002 type_leaf_003);
@xyz_idtypes=qw(type_x type_y type_z);
@idtypes=(@regular_idtypes,@leaf_idtypes,@xyz_idtypes);
@ids=qw(001 002);

@OPTIONS=qw(op=s validate);
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
1;
