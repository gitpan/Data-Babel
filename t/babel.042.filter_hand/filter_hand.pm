package filter_hand;
use t::util;
use t::utilBabel;
use Carp;
use Getopt::Long;
use List::Util qw(min);
use Set::Scalar;
use Test::More;
use Test::Deep qw(cmp_details deep_diag);
use Exporter();
use Class::AutoDB;
use Data::Babel;
use Data::Babel::Config;
use strict;
our @ISA=qw(Exporter);

our @EXPORT=qw(%OPTIONS @OPTIONS $autodb $babel $data @idtypes $idtypes_subsets 
	       @input_idtypes @output_idtypes @ids
	       init empty_result);
sub init {
  our %OPTIONS; 
  our @OPTIONS=qw(developer translate count history validate);
  GetOptions (\%OPTIONS,@OPTIONS);
  # translate is default
  $OPTIONS{translate}=1 unless $OPTIONS{count};

  # initialize variables used in most tests
  our @idtypes=qw(type_001 type_002 type_003 type_004);
  our $idtypes_subsets=Set::Scalar->new(@idtypes)->power_set;
  our @input_idtypes=$OPTIONS{developer}? @idtypes: @idtypes[0,2];
  our @output_idtypes=$OPTIONS{developer}?
    map {[$_->members]} grep {$_->size<=2} $idtypes_subsets->members :
      ([],map {[$_],['type_001',$_]} @idtypes);
  our @ids=qw(000 001 010 011 100 101 110 111);

  # create AutoDB database
  our $autodb=new Class::AutoDB(database=>'test',create=>1); 
  isa_ok($autodb,'Class::AutoDB','sanity test - $autodb');
  cleanup_db($autodb);		# cleanup database from previous test
  Data::Babel->autodb($autodb);
  my $dbh=$autodb->dbh;

  # create Babel directly from config files. this is is the usual case
  my $name='test';
  our $babel=new Data::Babel
    (name=>$name,
     idtypes=>File::Spec->catfile(scriptpath,'filter_hand.idtype.ini'),
     masters=>File::Spec->catfile(scriptpath,'filter_hand.master.ini'),
     maptables=>File::Spec->catfile(scriptpath,'filter_hand.maptable.ini'));
  isa_ok($babel,'Data::Babel','sanity test - Babel created from config files');

  # quietly test simple attributes
  cmp_quietly($babel->name,$name,'sanity test - Babel attribute: name');
  cmp_quietly($babel->id,"babel:$name",'sanity test - Babel attribute: id');
  cmp_quietly($babel->autodb,$autodb,'sanity test - Babel attribute: autodb');

  # setup the database
  our $data=new Data::Babel::Config
    (file=>File::Spec->catfile(scriptpath,'filter_hand.data.ini'))->autohash;
  load_handcrafted_maptables($babel,$data);
  load_handcrafted_masters($babel,$data);
  $babel->load_implicit_masters;
  load_ur($babel,'ur');

  # test ur construction for sanity
  my $correct=prep_tabledata($data->ur->data);
  my $actual=$dbh->selectall_arrayref(qq(SELECT type_001,type_002,type_003,type_004 FROM ur));
  cmp_table($actual,$correct,'sanity test - ur construction');

  # test ur selection for sanity
  my $correct=prep_tabledata($data->ur_selection->data);
  my $actual=select_ur_sanity(babel=>$babel,urname=>'ur',output_idtypes=>[qw(type_001 type_004)]);
  cmp_table($actual,$correct,'sanity test - ur selection');
}
########################################
# result can be table or count
sub empty_result {
  my $result=shift;
  ref $result? scalar @$result: $result;
}

1;
