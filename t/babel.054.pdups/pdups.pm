package pdups;
use t::util;
use t::utilBabel;
use Carp;
use Getopt::Long;
use Hash::AutoHash;
use List::MoreUtils qw(uniq);
use List::Util qw(min);
use Math::BaseCalc;
use POSIX qw(ceil);
use Set::Scalar;
use Test::More;
use Text::Abbrev;
use Class::AutoDB;
use Data::Babel;
use strict;
our @ISA=qw(Exporter);

our @EXPORT=qw($OPTIONS %OPTIONS @OPTIONS $OP $autodb $babel $dbh
               init doit);
our($OPTIONS,%OPTIONS,@OPTIONS,$OP,$autodb,$babel,$dbh,@filter_subsets,@output_subsets);

@OPTIONS=qw(op=s history validate
	    user_type=s graph_type=s link_type=s basecalc=i
	    max_filters=i max_outputs=i num_maptables=i arity=i);
our %op=abbrev qw(translate count);
our %user_type=abbrev qw(installer developer);
our %graph_type=abbrev qw(star chain tree);
our %link_type=abbrev qw(starlike chainlike);

# for some options, defaults depend on graph_type x user_type
our %DEFAULTS=
  (op=>'translate',
   user_type=>'installer',
   graph_type=>'star',
   "star$;installer"=>{max_outputs=>4,max_filters=>2,link_type=>'starlike',arity=>4,basecalc=>4,
		       num_maptables=>4},
   
   "star$;developer"=>{max_outputs=>4,max_filters=>3,link_type=>'starlike',arity=>4,basecalc=>4,
		       num_maptables=>4},

   "chain$;installer"=>{max_outputs=>4,max_filters=>2,link_type=>'chainlike',arity=>1,basecalc=>4,
			num_maptables=>4},

   "chain$;developer"=>{max_outputs=>4,max_filters=>3,link_type=>'chainlike',arity=>1,basecalc=>4,
			num_maptables=>4},

   "tree$;installer"=>{max_outputs=>4,max_filters=>1,link_type=>'starlike',arity=>2,basecalc=>2,
		       num_maptables=>5},
   
   "tree$;developer"=>{max_outputs=>4,max_filters=>2,link_type=>'starlike',arity=>2,basecalc=>2,
		       num_maptables=>7},
  );

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
  GetOptions(\%OPTIONS,@OPTIONS);
  # set defaults that don't depend on graph_type x user_type
  map {$OPTIONS{$_}=$DEFAULTS{$_} unless defined $OPTIONS{$_}} 
    qw(op user_type graph_type basecalc);
  # expand abbreviations
  for my $option (qw(op user_type db_type graph_type link_type)) {
    next unless defined $OPTIONS{$option};
    my %abbrev=eval "\%$option";
    $OPTIONS{$option}=$abbrev{$OPTIONS{$option}} or confess "illegal value for option $option";
  }
  # set defaults that depend on graph_type x user_type
  my %defaults=%{$DEFAULTS{"$OPTIONS{graph_type}$;$OPTIONS{user_type}"}};
  map {$OPTIONS{$_}=$defaults{$_} unless exists $OPTIONS{$_}} keys %defaults;
  
  # set special-case defaults
  # $OPTIONS{filter}=1 if !defined($OPTIONS{filter}) && scriptbasename=~/filter/;

  $OP=$OPTIONS{op};
  $OPTIONS=new Hash::AutoHash %OPTIONS;
}

# args are idtypes. always gets all input_ids
sub doit {
  my($input_idtype,$filter_idtypes,$output_idtypes,$file,$line)=@_;
  my $input_ids=input_ids($input_idtype);
  my $filters=defined $filter_idtypes? make_filters($filter_idtypes): undef;
  my $ok=1;
  # get idtype names for use in label
  my $input_name=$input_idtype->name;
  my @output_names=map {$_->name} @$output_idtypes;
  my @filter_names=map {$_->name} @$filter_idtypes;
  my $label="input=$input_name, filters=@filter_names, outputs=@output_names";

  my @args=(input_idtype=>$input_idtype,input_ids=>$input_ids,filters=>$filters,
	    output_idtypes=>$output_idtypes);
  push(@args,validate=>1) if $OPTIONS->validate;
  my $correct=select_ur(babel=>$babel,@args);
  my $actual=$babel->$OP(@args);
  $ok&&=cmp_op_quietly($actual,$correct,$OP,"$OP $label",$file,$line);
  $ok;
}

# get input ids for an idtype. everything in master plus some that don't match for validate
sub input_ids {
  my($idtype)=@_;
  my $table=$idtype->master->name;
  my $input_ids=$dbh->selectcol_arrayref(qq(SELECT * from $table));
  push(@$input_ids,qw(INVALID_001 INVALID_002));
  $input_ids;
}
# make filters HASH.  $idtypes is ARRAY of filter_idtypes
# in basecalc db, each digit selects approx 1/basecalc rows
sub make_filters {
  my($idtypes)=@_;
  my $filters={};
  for my $idtype (@$idtypes) {
    my $name=$idtype->name;
    my $id="$name/d_0";		# any digit would do
    $filters->{$name}=[$id];
  }
  $filters;
}
