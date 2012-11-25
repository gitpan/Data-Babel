package translate_hand;
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
	       $data @idtypes @idtypes_subsets @filter_subsets @output_subsets @ids
	       init make_ids make_invalid_ids empty_result);
our($OPTIONS,%OPTIONS,@OPTIONS,$OP,$autodb,$babel,$dbh,$data,@idtypes,
    @idtypes_subsets,@filter_subsets,@output_subsets,@ids);
@idtypes=qw(type_001 type_002 type_003 type_004);
@ids=qw(000 001 010 011 100 101 110 111);

@OPTIONS=qw(op=s history validate user_type=s max_ids=i max_filters=i max_outputs=i);
our %op=abbrev qw(translate count);
our %user_type=abbrev qw(installer developer);
# for some options, defaults depend on user_type
our %DEFAULTS=(op=>'translate',user_type=>'installer',
	       installer=>{max_ids=>2,max_outputs=>2,max_filters=>2},
	       developer=>{max_ids=>scalar(@ids),
			   max_outputs=>scalar(@idtypes),max_filters=>scalar(@idtypes)}
	      );

sub init {
  my $setup=shift @_;
  $OPTIONS=get_options();
  my $power_set=Set::Scalar->new(@idtypes)->power_set;
  @idtypes_subsets=$power_set->members;
  @filter_subsets=grep {$_->size<=$OPTIONS->max_filters} @idtypes_subsets;
  @output_subsets=grep {$_->size<=$OPTIONS->max_outputs} @idtypes_subsets;
  unless ($setup) {
    $autodb=new Class::AutoDB(database=>'test'); 
    isa_ok($autodb,'Class::AutoDB','sanity test - $autodb');
    # expect 'old' to return the babel
    $babel=old Data::Babel(name=>'test',autodb=>$autodb);
    isa_ok($babel,'Data::Babel','sanity test - old Babel returned Babel object');
    my @idtypes=@{$babel->idtypes};
    is_quietly(scalar @idtypes,4,'BAD NEWS old Babel has wrong number of idtypes!!');
    my @maptables=@{$babel->maptables};
    is_quietly(scalar @maptables,3,'BAD NEWS old Babel has wrong number of maptables!!');
  } else {			# setup new database
    $autodb=new Class::AutoDB(database=>'test',create=>1); 
    isa_ok($autodb,'Class::AutoDB','sanity test - $autodb');
    cleanup_db($autodb);		# cleanup database from previous test
    Data::Babel->autodb($autodb);
    # rest of setup done by test
  }
  $dbh=$autodb->dbh;
  my $data_ini=!$OPTIONS{history}? 'translate_hand.data.ini': 'translate_hand.data_history.ini';
  $data=new Data::Babel::Config(file=>File::Spec->catfile(scriptpath,$data_ini))->autohash;
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
  # set defaults that depend on user_type
  my %defaults=%{$DEFAULTS{$OPTIONS{user_type}}};
  map {$OPTIONS{$_}=$defaults{$_} unless exists $OPTIONS{$_}} keys %defaults;
 
  # set special-case defaults
  # $OPTIONS{filter}=1 if !defined($OPTIONS{filter}) && scriptbasename=~/filter/;

  $OP=$OPTIONS{op};
  $OPTIONS=new Hash::AutoHash %OPTIONS;
}
# convert idtype & id indexes to ids. if no indexes, convert all ids
sub make_ids {
  my $idtype=shift;
  my $id_prefix=($OPTIONS->history && grep {$idtype eq $_} qw(type_001 type_002))? 
    "${idtype}/x_": "${idtype}/a_";
  @_? map {"${id_prefix}$_"} @ids[@_]: map {"${id_prefix}$_"} @ids;
}
sub make_invalid_ids {
  my($idtype,$num)=@_;
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
