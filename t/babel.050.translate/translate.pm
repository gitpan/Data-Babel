package translate;
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
	       @filter_subsets @output_subsets 
	       maptable_data master_data idtype2ids
               init doit make_filter);
our($OPTIONS,%OPTIONS,@OPTIONS,$OP,$autodb,$babel,$dbh,@filter_subsets,@output_subsets);

@OPTIONS=qw(op=s history validate
		user_type=s db_type=s graph_type=s link_type=s basecalc=i
		max_filters=i max_outputs=i num_maptables=i arity=i);
our %op=abbrev qw(translate count);
our %user_type=abbrev qw(installer developer);
our %db_type=abbrev qw(binary staggered basecalc);
our %graph_type=abbrev qw(star chain tree);
our %link_type=abbrev qw(starlike chainlike);

# for some options, defaults depend on graph_type x user_type
our %DEFAULTS=
  (op=>'translate',
   user_type=>'installer',
   db_type=>'binary',
   graph_type=>'star',
   basecalc=>4,
   "star$;installer"=>{max_outputs=>2,max_filters=>2,db_type=>'basecalc',
		       link_type=>'starlike',arity=>4,num_maptables=>4},
   
   "star$;developer"=>{max_outputs=>2,max_filters=>3,db_type=>'basecalc',
		       link_type=>'starlike',arity=>4,num_maptables=>4},

   "chain$;installer"=>{max_outputs=>2,max_filters=>2,db_type=>'binary',
			link_type=>'chainlike',arity=>1,num_maptables=>4},

   "chain$;developer"=>{max_outputs=>2,max_filters=>3,db_type=>'binary',
			link_type=>'chainlike',arity=>1,num_maptables=>4},

   "tree$;installer"=>{max_outputs=>1,max_filters=>1,db_type=>'staggered',
		       link_type=>'starlike',arity=>2,num_maptables=>5},
   
   "tree$;developer"=>{max_outputs=>2,max_filters=>2,db_type=>'staggered',
		       link_type=>'starlike',arity=>2,num_maptables=>7},
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
    my @idtypes=@{$babel->idtypes};
    my @maptables=@{$babel->maptables};
    is(scalar @maptables,$OPTIONS->num_maptables,
       'sanity test - old Babel has expected number of maptables');
    my $power_set=Set::Scalar->new(@idtypes)->power_set;
    @filter_subsets=grep {$_->size<=$OPTIONS->max_filters} $power_set->members;
    @output_subsets=grep {$_->size<=$OPTIONS->max_outputs} $power_set->members;
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

# args are idtypes
sub doit {
  my($input_idtype,$input_ids,$filters,$output_idtypes,$file,$line)=@_;
  $filters={} unless defined $filters;
  my $ok=1;
  # get idtype names for use in label
  my $input_name=$input_idtype->name;
  my @output_names=map {$_->name} @$output_idtypes;
  my @filter_names=keys %$filters;
  
  my(@args,$label);
  if ($input_ids ne 'all') {
    @args=(input_idtype=>$input_idtype,input_ids=>$input_ids,filters=>$filters,
	   output_idtypes=>$output_idtypes);
    $label=$OPTIONS->db_type.": input=$input_name, num input_ids=".
      (defined($input_ids)? scalar(@$input_ids): 0).
	" filters=@filter_names, outputs=@output_names";
  } else {
    @args=(input_idtype=>$input_idtype,input_ids_all=>1,filters=>$filters,
	   output_idtypes=>$output_idtypes);
    $label=$OPTIONS->db_type.": input=$input_name, input_ids_all=1, filters=@filter_names, outputs=@output_names";
  }
  push(@args,validate=>1) if $OPTIONS->validate;
  my $correct=select_ur(babel=>$babel,@args);
  my $actual=$babel->$OP(@args);
  $ok&&=cmp_op_quietly($actual,$correct,$OP,"$OP $label",$file,$line);
  $ok;
}

########################################
# these functions generate data loaded into database or used in queries
########################################
# arg is maptable number
sub maptable_data {
  my($i)=@_;
  my $maptable=$babel->name2maptable('maptable_'.sprintf('%03d',$i));
  my @idtype_names=map {$_->name} @{$maptable->idtypes};
  my @data;
  unless ($OPTIONS->db_type eq 'basecalc') {
    my @series=data_series($i);	# make data series for $OPTIONS->db_type
    # for each value in series, create a row
    for my $val (@series) {
      push(@data,[map {"$_/$val"} @idtype_names]);
    }
  } else { # all strings of length @idtype_names digits over base $basecalc
    my $calc=new Math::BaseCalc(digits=>[0..$OPTIONS->basecalc-1]);
    my $numdigits=@idtype_names;
    for (my $i=0; $i<$OPTIONS->basecalc**$numdigits; $i++) {
      my @digits=split('',sprintf("%0.*i",$numdigits,$calc->to_base($i)));
      push(@data,[map {"$idtype_names[$_]/d_$digits[$_]"} 0..$numdigits-1]);
    }
  }
  # add in 'multi' rows: links are 'multi','multi'; leafs are 'multi_000','multi_001']
  push(@data,[map {/^leaf/? "$_/multi_000": "$_/multi"} @idtype_names]);
  push(@data,[map {/^leaf/? "$_/multi_001": "$_/multi"} @idtype_names]);
  \@data;
}
# arg is Master object
sub master_data {
  # my $name=ref $_[0]? $_[0]->idtype->name: 'leaf_'.sprintf('%03d',$_[0]);
  confess "obsolete call to master_data. arg must be Master object, not $_[0]" unless ref $_[0];
  my $name=$_[0]->idtype->name;
  my @series=data_series();	# make data series for $OPTIONS->db_type
  # my @series=$OPTIONS->db_type eq 'staggered'? staggered_series(): binary_series();
  # my @extras=(qw(none_000 none_001),$name=~/^leaf/? qw(multi_000 multi_001): qw(multi));
  my @multis=$name=~/^leaf/? qw(multi_000 multi_001): qw(multi);
  my @nones=qw(none_000 none_001);
  my @data=!$OPTIONS->history? (map {"${name}/$_"} (@series,@multis,@nones)):
    ((map {["_x_${name}/$_","${name}/$_"]} (@series,@multis)),
     map {["_x_${name}/$_",'NULL']} @nones);
  # wantarray? @data: \@data;
  \@data;
}
# generate input ids for IN clause. many don't match anything.
# NG 12-11-21: add histories
# arg is IdType
sub idtype2ids {
  my($idtype)=@_;
  # master_data($idtype);
  my $name=$idtype->name;
  my $prefix=!$OPTIONS->history? $name: "_x_$name";
  my @series=data_series();	# make data series for $OPTIONS->db_type
  my @extras=(qw(none_000 none_001),$name=~/^leaf/? qw(multi_000 multi_001): qw(multi));
  my @data=map {"${prefix}/$_"} (@series,@extras);
  \@data;
}

# generate series of raw values for use in maptables, masters, and IN clauses
sub data_series {
  my($i)=@_;
  eval $OPTIONS->db_type.'_series($i)';
}
sub binary_series {
  my($i)=@_;
  my @series=_binary_series($OPTIONS->num_maptables,$i);
  map {"a_$_"} @series;
}
sub staggered_series {
  my($i)=@_;
  my $last_maptable=$OPTIONS->num_maptables-1;
  defined $i?
    ((map {'b_'.sprintf('%03d',$_)} ($i..$last_maptable)),
     (map {'c_'.sprintf('%03d',$last_maptable-$_)} (0..$i))):
       (map {('b_'.sprintf('%03d',$_),'c_'.sprintf('%03d',$_))} (0..$last_maptable));
}
sub basecalc_series {
  map {"d_$_"} 0..$OPTIONS->basecalc-1;
}
sub _binary_series {
  my($bits,$my_bit)=@_;
  if (defined $my_bit) {	# return $bits-wide numbers with $my_bit set
    my $mask=1<<$my_bit;
    return map {sprintf '%0*b',$bits,$_} grep {$_&$mask} (0..2**$bits-1);
  } else {			# return all $bits-wide numbers
    return map {sprintf '%0*b',$bits,$_} (0..2**$bits-1);
  }
}

# for debugging. args are number of bits, and number to convert
sub as_binary_string {sprintf '%0*b',@_}

########################################
# these functions used by filter tests to get filter ids that generate
#   results of desired size
########################################
# make filters HASH. 
#   $filters arg is ARRAY of filter_idtypes
#   $fraction is target fraction of table cut by each filter 
#   if $multi_ok is true, okay to include 'multi' ids
#     $fraction, $multi_ok not used when db_type is basecalc
sub make_filter {
  my($input,$input_ids,$filters,$outputs,$multi_ok,$fraction)=@_;
  $input_ids=undef if $input_ids eq 'all';
  my $table=select_ur(babel=>$babel,input_idtype=>$input,input_ids=>$input_ids,
		      output_idtypes=>[@$filters,@$outputs]);
  my $filter={};
  for(my $i=0; $i<@$filters; $i++) {
    my $filter_ids=
      $OPTIONS->db_type ne 'basecalc' ?
	choose_filter_ids($table,$i+1,$multi_ok,$fraction):
	  # in basecalc db, each digit selects approx 1/basecalc rows
	  [$filters->[$i]->name.'/d_0']; # any digit would do
    @$filter_ids=map {"_x_$_"} @$filter_ids if $filters->[$i]->history;
    $filter->{$filters->[$i]->name}=$filter_ids;
    $table=grep_table($table,$i+1,$filter_ids);
  }
  $filter;
}

# choose ids from column $col of $table that approximately cut the table to $fraction
# if $multi_ok is true, okay to include 'multi' ids
# if all ids are NULL, use undef - will match NULLS
sub choose_filter_ids {
  my($table,$col,$multi_ok,$fraction)=@_;
  $fraction=0.5 unless defined $fraction;
  my $nrows=ceil($fraction*scalar(@$table));
  my @all_ids=grep {defined $_} map {$_->[$col]} @$table;
  @all_ids=grep !/multi/,@all_ids unless $multi_ok;
  @all_ids? [uniq(@all_ids[0..min($#all_ids,$nrows-1)])]: [undef];
}
sub grep_table {
  my($table,$col,$ids)=@_;
  my $pattern=join('|',map {"\^$_\$"} @$ids);
  $pattern=qr/$pattern/;
  [grep {$_->[$col]=~/$pattern/} @$table];
}

