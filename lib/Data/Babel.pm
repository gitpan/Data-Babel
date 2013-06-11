package Data::Babel;
our $VERSION='1.11_01';
$VERSION=eval $VERSION;         # I think this is the accepted idiom..
#################################################################################
#
# Author:  Nat Goodman
# Created: 10-07-26
# $Id: 
#
# Copyright 2010 Institute for Systems Biology
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either: the GNU General Public License as published
# by the Free Software Foundation; or the Artistic License.
#
# See http://dev.perl.org/licenses/ for more information.
#
#################################################################################
use strict;
use Class::AutoClass;
use Carp;
use Graph::Undirected;
use List::MoreUtils qw(uniq);
use List::Util qw(min);
use Hash::AutoHash::Args;
use Hash::AutoHash::MultiValued;
use Data::Babel::Config;
use Data::Babel::IdType;
use Data::Babel::Master;
use Data::Babel::MapTable;
use Data::Babel::HAH_MultiValued;

use vars qw(@AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS %AUTODB);
use base qw(Data::Babel::Base);

# name, id, autodb, verbose - methods defined in Base
@AUTO_ATTRIBUTES=qw();
@OTHER_ATTRIBUTES=qw(idtypes masters maptables schema_graph);
%SYNONYMS=();
%DEFAULTS=(idtypes=>[],masters=>[],maptables=>[],);
%AUTODB=(-collection=>'Babel',-keys=>qq(name string),-transients=>qq());
Class::AutoClass::declare;

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  # NG 10-08-02: due to Class::AutoClass bug, setting __OVERRIDE__ in Base
  #              does NOT change $self here. so do it explicitly here!
  # TODO: remove this hack when Class::AutoClass bug fixed
  $self=$self->{__OVERRIDE__} if $self->{__OVERRIDE__};

  # connect component objects to Babel
  for my $component_attr (qw(idtypes masters maptables)) {
    map {$_->babel($self)} @{$self->$component_attr};
  }
  # connect Masters to their IdTypes & vice versa
  map {$_->connect_idtype} @{$self->masters};
  map {$_->idtype->connect_master} @{$self->masters};
  # NG 13-06-11: check for unkown IdTypes before connecting to MapTables
  my @unknowns=uniq(map {$_->unknown_idtypes} @{$self->maptables});
  confess "Unknown IdType(s) appear in MapTables: ",join(', ',@unknowns) if @unknowns;
  # connect MapTables to their IdTypes and vice versa
  map {$_->connect_idtypes} @{$self->maptables};
  for my $maptable (@{$self->maptables}) {
    map {$_->add_maptable($maptable)} @{$maptable->idtypes};
  }
  # NG 13-06-11: check for isolated IdTypes
  my @isolateds=grep {$_->degree==0} @{$self->idtypes};
  confess "Some IdType(s) are 'isolated', ie, not in any MapTable: ",
    join(', ',map {$_->name} @isolateds) if @isolateds;
  # create schema graph
  $self->schema_graph;
  # make implicit masters and connect them up
  $self->make_implicit_masters;
  # store Babel and component objects
  # NG 10-08-24: only store if autodb set
  if (my $autodb=$self->autodb) {
    $autodb->put($self,@{$self->idtypes},@{$self->masters},@{$self->maptables});
  }
}

# methods to get/set component objects.
# parameters for set can be
# 1) objects of appropriate type
# 2) any file descriptor handled by Config::IniFiles::new, typically filename
# 3) list or ARRAY of above in any combination
sub idtypes {
  my $self=shift;
  @_? $self->{idtypes}=_make_objects('IdType',@_): $self->{idtypes};
}
sub masters {
  my $self=shift;
  @_? $self->{masters}=_make_objects('Master',@_): $self->{masters};
}
sub maptables {
  my $self=shift;
  @_? $self->{maptables}=_make_objects('MapTable',@_): $self->{maptables};
}

sub _make_objects {
  my $class=shift;
  $class="Data::Babel::$class" unless $class=~/^Data::Babel::/;
  @_=@{$_[0]} if 'ARRAY' eq ref $_[0]; # flatten ARRAY
  my @objects;
  for (@_) {
    push(@objects,$_),next if ref($_) && $_->isa($class);
    # else let Config handle it
    push(@objects,@{new Data::Babel::Config(file=>$_)->objects($class)});
  }
  \@objects;
}

sub name2idtype {shift->_name2object('idtype',@_)}
sub name2master {shift->_name2object('master',@_)}
sub name2maptable {shift->_name2object('maptable',@_)}
sub id2object {shift->_name2object(split(':',$_[0]));} # used to translate nodes to objects
# NG 10-11-03: bug found by Denise. in Perls > 5.12, split no longer puts result in @_
# sub id2name {shift; split(':',$_[0]); pop(@_)}
sub id2name {shift; my @x=split(':',$_[0]); pop(@x)}

# NG 11-01-21: added 'translate all'. ie, input_ids_all arg
sub translate { 
  my $self=shift;
  my $args=new Hash::AutoHash::Args(@_);
  # NG 11-01-21: do arg checking here
  # NG 12-10-31: output_idtypes not really required. in any case, it can be empty
  # my $missing_args=join(', ',grep {!$args->$_} qw(input_idtype output_idtypes));
  confess "Required argument input_idtype missing" unless $args->input_idtype;
  $args->output_idtypes([]) unless defined $args->output_idtypes;
  my $ids_args=grep {$args->$_} qw(input_ids input_ids_all);
  # NG 12-08-22: okay to omit input_ids; same as input_ids_all=>1
  # confess "At least one of input_ids or input_ids_all must be set" if $ids_args==0;
  confess "At most one of input_ids or input_ids_all may be set" if $ids_args>1;
  my $sql=$self->generate_query($args);
  my $dbh=$args->dbh || $self->autodb->dbh;
  # my $results=$args->count? $dbh->selectrow_array($sql): $dbh->selectall_arrayref($sql);
  # NG 13-06-11: added this code to display query
  if ($self->verbose) {
    print "$sql\n";
  }
  my $results=$dbh->selectall_arrayref($sql);
  confess "Database query failed:\n$sql\n".$dbh->errstr if $dbh->err;
  unless ($args->validate) {
    $results=@$results? $results->[0][0]: 0 if $args->count;
  } else { 
    # cases:
    # 1) no filters. $results contains all valid input_ids. missing ids are invalid
    # 2) filters. $results contains subset of valid input_ids. have to query db to
    #    get all valid ones
    # initial code needed for all cases
    my $input_ids=$args->input_ids;
    my @input_ids=ref $input_ids? uniq(@$input_ids): defined $input_ids? ($input_ids): ();
    my $num_outputs=ref $args->output_idtypes? @{$args->output_idtypes}: 0;

    # %have_id tells which input ids are in result
    # @missing_ids are input ids not in result - some are valid, some not
    # %id2valid maps input ids to validity
    # NG 13-06-10: convert to lower case for case insensitive comparisons
    my %have_id=map {lc $_->[0]=>1} @$results;
    my @missing_ids;
    my %id2valid;

    if (!$args->filters) {
      %id2valid=%have_id;
    } else {
      my $input_idtype=$self->_2idtype($args->input_idtype);
      my $input_colname=_generate_colname($input_idtype);
      my $input_tablename=$input_idtype->tablename;
      my $sql=qq(SELECT DISTINCT $input_colname FROM $input_tablename);
      if (@input_ids) {
	my @input_ids_sql=map {$dbh->quote($_)} @input_ids;
	my $where= "WHERE $input_colname IN ".'('.join(', ',@input_ids_sql).')';
	$sql.="\n$where";
      }
      my $valid_ids=$dbh->selectcol_arrayref($sql);
      confess "Database query failed:\n$sql\n".$dbh->errstr if $dbh->err;
      %id2valid=map {$_=>1} @$valid_ids;
      @input_ids=@$valid_ids unless defined $input_ids;
    }
    # NG 13-06-10: convert to lower case for case insensitive comparisons
    @missing_ids=grep {!$have_id{lc $_}} @input_ids;
    push(@$results,map {[$_,$id2valid{lc $_}||0,(undef)x$num_outputs]} @missing_ids);
 
    # post-processing
    # 1) count. return number of rows
    # 2) limit. select subset of rows
    # 3) count+limit: return min of count, limit
    if ($args->count) {
      $results=scalar @$results;
      $results=min($args->limit,$results) if defined $args->limit;
    } elsif (defined $args->limit) {
      @$results=@$results[0..min($args->limit,scalar @$results)-1];
    }
  }
  $results;
}
sub count {
  my $self=shift;
  my $args=new Hash::AutoHash::Args(@_);
  $args->count(1);
  $self->translate($args);
}
sub validate {
  my $self=shift;
  my $args=new Hash::AutoHash::Args(@_);
  confess "Required argument input_idtype missing" unless $args->input_idtype;
  $args->validate(1);
  $args->output_idtypes([$args->input_idtype]) unless defined $args->output_idtypes;
  $self->translate($args);
}
sub generate_query {
  my($self,$args)=@_;
  # be careful about objects vs. names
  # use variables xxx_idtype for objects, xxx_name for names
  my $input_idtype=$self->_2idtype($args->input_idtype);
  my $input_name=_generate_colname($input_idtype);
  my $input_ids=$args->input_ids;
  $input_ids=[$input_ids] if defined $input_ids && !ref $input_ids;
  
  my $filters=$args->filters;
  # make sure all filter keys are names and values undef or ARRAYS - simplifies later code
  $filters=new Data::Babel::HAH_MultiValued $filters;
  my @filter_keys=keys %$filters;
  my @filter_idtypes=map {$self->_2idtype($_)} @filter_keys;
  # my @filter_names=map {$_->name} @filter_idtypes;
  my @filter_names=map {_generate_colname($_)} @filter_idtypes;
  $filters=new Data::Babel::HAH_MultiValued
    (map {$filter_names[$_]=>$filters->{$filter_keys[$_]}} (0..$#filter_keys));

  my @output_idtypes=map {$self->_2idtype($_)} @{$args->output_idtypes};
  my @output_names=map {$_->name} @output_idtypes;
  my @idtypes=uniq($input_idtype,@output_idtypes,@filter_idtypes);
  confess "Not enough types specified" unless @idtypes;

  my $dbh=$self->autodb->dbh;
  my @columns=($input_name,@output_names);
  # splice in VALID column if validating
  splice(@columns,1,0,'1 AS VALID') if $args->validate;
  # MySQL doesn't allow duplicate columns in inner queries. sigh..
  @columns=uniq(@columns) if $args->count;
  my $columns_sql=join(', ',@columns);
  
  my $input_master=$input_idtype->master;
  # start with input master if 'informative': explicit || degree>1. 
  # always use if single idtype or user wants all input_ids
  my @join_tables=
    ($input_master->explicit || $input_idtype->degree>1 || @idtypes==1 || !defined($input_ids))?
      $input_master->tablename: ();
  # get rest of query by exploring query graph
  push(@join_tables,map {$self->id2name($_)} 
       $self->traverse($self->make_query_graph(@idtypes))) if @idtypes>1;
  # add in filter masters for any with histories
  push(@join_tables,map {$_->tablename} grep {$input_idtype != $_} @filter_idtypes);
  my $join_sql=join(' NATURAL LEFT OUTER JOIN ',@join_tables);
  # NG 10-08-19: need to quote everything unless we're willing to check the SQL type
  #              'cuz, if column is string and input_id is number, MySQL converts the 
  #              string to a number (not vice versa which makes much more sense !!!!).
  #              since most strings convert to 0, this means that an input_id of 0
  #              matches almost everything
  # NG 11-01-21: add 'translate all'
  my @conds;			# WHERE clauses
  if (defined $input_ids) {
    my @input_ids=map {$dbh->quote($_)} @$input_ids;
    my $cond=@input_ids?
      " $input_name IN ".'('.join(', ',@input_ids).')': ' FALSE';
    push(@conds,$cond);
  }
  # NG 12-08-24: support filters
  # NG 12-09-21: handle undefs
  for my $filter_name (@filter_names) {
    my $cond;
    my $filter_ids=$filters->$filter_name;
    if (!defined $filter_ids) {
      $cond="$filter_name IS NOT NULL";
    } elsif (@$filter_ids) {
      my @cond;
      my @defined_ids=map {$dbh->quote($_)} grep {defined $_} @$filter_ids;
      push(@cond," $filter_name IN ".'('.join(', ',@defined_ids).')') if @defined_ids;
      push(@cond,"$filter_name IS NULL") if @defined_ids!=@$filter_ids;
      $cond=join(' OR ',@cond);
      $cond="($cond)" if @cond>1;
    } else {			# it's filter=>undef[]
      $cond="FALSE";
    }
    push(@conds,$cond);
  }
  # NG 10-11-10: skip rows whose output columns are all NULL
  # NG 12-11-23: but keep these rows if validating
  if (@output_names && !$args->validate)  {
    my $sql_not_null=join(' OR ',map {"$_ IS NOT NULL"} @output_names);
    push(@conds,"($sql_not_null)");
  }
  my $sql="SELECT DISTINCT $columns_sql FROM $join_sql";
  $sql.=' WHERE '.join(' AND ',@conds) if @conds;

  # NG 10-11-08: support limit. based on DM's change
  # NG 12-11-23: if validating, have to do limit in code...
  my $limit=$args->limit;
  confess "Invalid limit: $limit" if defined $limit && $limit=~/\D/;
  $sql.=" LIMIT $limit" if defined $limit && !$args->validate;

  # NG 12-09-23: support count
  # Note: 'AS T' needed at end of query because mySQL sees inner select as defining derived
  #       table and requires every derived table have alias
  # NG 12-11-23: if validating, have to do count in code...
  $sql=qq(SELECT COUNT(*) FROM ($sql) AS T) if $args->count && !$args->validate;
  
  $sql;
}
# input is IdType object. handles history
sub _generate_colname {
  my $idtype=shift;
  !$idtype->history? $idtype->name: '_X_'.$idtype->name;
}
# we're using a modified (bipartite) schema graph. nodes are IdTypes and MapTables.
# edges go between MapTables and the IdTypes they contain
# use persistent ids for nodes (rather than objects) so it will work when fetched from db 
sub schema_graph {
  my $self=shift;
  my $schema_graph=@_? $self->{schema_graph}=shift: $self->{schema_graph};
  unless ($schema_graph) {	# not yet initialized. do it now
    $schema_graph=$self->{schema_graph}=new Graph::Undirected;
    my @maptables=@{$self->maptables};
    for my $maptable (@maptables) {
      my $maptable_id=$maptable->id;
      map {$schema_graph->add_edge($maptable_id,$_->id)} @{$maptable->idtypes};
    }}
  $schema_graph;
 }

# query graph is a steiner minimum tree whose terminals are the input and output IdTypes
# trivial to compute for __non_redundant__ schema. just prune back non-terminal leaves
# first arg is input_idtype; rest are output_idtypes. specified as objects!
# returns ($root,$query_graph)
sub make_query_graph {
  my $self=shift;
  my @terminals=map {$_->id} @_; # nodes. not objects
  my %terminals=map {$_=>1} @terminals;
  my $input_idtype=$_[0];	 # 1st idtype is input. save for later as object...
  my $input_node=$terminals[0];	 # ...and node

  my $query_graph=$self->schema_graph->copy;
  my @leaves=grep {$query_graph->degree($_)==1} $query_graph->vertices;
  while (@leaves) {
    my $leaf=shift @leaves;
    if (!$terminals{$leaf}) {	                   # not terminal, so prune
      my($parent)=$query_graph->neighbors($leaf);  # hold onto parent for a moment
      $query_graph->delete_vertex($leaf);
      unshift(@leaves,$parent) if $query_graph->degree($parent)<=1;
      # TODO: obvious optimization: delete parent immediately w/o putting it on @leaves
    }}
  # NG 10-08-16: original logic not quite right. need Master whenever 'informative'
  #              to achieve correct UR semantics. processing moved to generate_query.
  #              now use any neighbor of input IdType
  my($root)=$query_graph->neighbors($input_node);
#  # root processing: if input_idtype touches >1 maptable, add master as root
#  #                  else use the input_idtype's maptable as root
#   my $root;
#   if ($query_graph->degree($input_node)>1) {
#     my $master_obj=$input_idtype->master or 
#       confess "No Master found for input IdType ".$input_idtype->name;
#     $root=$master_obj->id;
#     $query_graph->add_edge($root,$input_node);
#   } else {
#     ($root)=$query_graph->neighbors($input_node);
#   } 
  ($root,$query_graph);
}

# make implicit masters
#   every IdType needs a Master. if Master not defined explicitly, define it here
#   if IdType joins 2 or more MapTables, Master is TABLE (UNION over MapTables)
#   if IdType contained in 1 MapTable, Master is VIEW
# NG 10-11-10: added clauses to exclude NULLs
# NG 13-06-11: renamed to make_implicit_masters
sub make_implicit_masters {
  my $self=shift;
  my $schema_graph=$self->schema_graph;
  my %idtype2master=map {$_->idtype->name => $_} @{$self->masters};
  my @need_imps=grep {!$idtype2master{$_->name}} @{$self->idtypes};
  for my $idtype (@need_imps) {
    my $idtype_name=$idtype->name;
    my @maptables=map {$self->id2object($_)} $schema_graph->neighbors($idtype->id);
    my $view=@maptables==1? 1: 0;
    my $inputs=join("\n",map {$_->namespace.'/'.$_->name} @maptables);
    my $query=$view? 
      "SELECT DISTINCT $idtype_name FROM ".$maptables[0]->name." WHERE $idtype_name IS NOT NULL" :
      join("\nUNION\n",
	   map {"SELECT $idtype_name FROM ".$_->name." WHERE $idtype_name IS NOT NULL"}
	   @maptables);
    my $master=new Data::Babel::Master
      (name=>$idtype->name.'_master',implicit=>1,
       inputs=>$inputs,query=>$query,view=>$view,
       babel=>$self,idtype=>$idtype);
    push(@{$self->masters},$master); # connect new Master to Babel
    $self->name2master($master);     # add new Master to name hash
    $idtype->master($master);	     # connect new Master to its IdType
  }
}
# NG 12-09-27: added load_implicit_masters
sub load_implicit_masters {
  my $self=shift;
  my $dbh=$self->dbh;
  my @implicits=grep {$_->implicit} @{$self->masters};
  for my $master (@implicits) {
    my $tablename=$master->tablename;
    my $idtype=$master->idtype;
    my $column_name=$idtype->name;
    my $column_sql_type=$idtype->sql_type;
    my $query=$master->query;
    my $sql=$master->view?
      qq(CREATE VIEW $tablename): 
	qq(CREATE TABLE $tablename ($column_name $column_sql_type));
    $sql.=" AS\n$query";
    $dbh->do(qq(DROP VIEW IF EXISTS $tablename));
    $dbh->do(qq(DROP TABLE IF EXISTS $tablename));
    $dbh->do($sql);
    if (my $errstr=$dbh->errstr) {
      confess "Unable to create Master $tablename: $errstr";
    }
    $dbh->do(qq(ALTER TABLE $tablename ADD INDEX ($column_name)));
  }
}

sub show { 
  my $self=shift;
  print "IdTypes:\n",'  ',join(', ',sort map {$_->name} @{$self->idtypes}),"\n";
  print "\nExplicit Masters:\n",
    join("\n",sort map {'  '.$_->tablename.' ('.$_->idtype->name.': degree='.$_->degree.')'} 
	 grep {$_->explicit} @{$self->masters});
  print "\nImplicit Masters (tables):\n",
    join("\n",sort map {'  '.$_->tablename.' ('.$_->idtype->name.': degree='.$_->degree.')'} 
	 grep {$_->implicit && !$_->view} @{$self->masters});
  print "\nImplicit Masters (views):\n",
    join("\n",sort map {'  '.$_->tablename.' ('.$_->idtype->name.': degree='.$_->degree.')'} 
	 grep {$_->implicit && $_->view} @{$self->masters});
  print "\n";
  print "\nMapTables:\n",
    join("\n",sort map {'  '.$_->tablename.' ('.
			  join(', ',map {$_->name} @{$_->idtypes}).')'} @{$self->maptables}),
      "\n";
  print "\nschema_graph:\n";
  show_graph($self->schema_graph);
}
# NG 13-06-11: emit schema graph in SIF - currently very simple, basically proof of concept
sub show_schema_graph {
  my($self,$file,$format)=@_;
  length($format)? $format=lc($format): ($format='sif');
  confess "Invalid format $format: must be sif or txt" unless $format=~/sif|txt/;
  if ($file) {
    open(OUT,'>',$file) || confess "Cannot create output file $file: $!";
  } else {
    *OUT=*STDOUT;
  }
  my $graph=$self->schema_graph;
  if ($format eq 'sif') {
    print OUT join("\n",map {my($v0,$v1)=@$_;"$v0 - $v1"} $graph->edges),"\n";
  } else {
    print OUT '  ',join("\n  ",map {_edge_str($graph,$_)} _sort_edges($graph->edges)),"\n";
  }
  close OUT if $file;
}

# can be called as function or method
sub show_graph {
  my $graph=ref($_[0]) && $_[0]->isa('Graph')? $_[0]: $_[1];
  print '  ',join("\n",map {_edge_str($graph,$_)} _sort_edges($graph->edges)),"\n";
}
sub _sort_edges {
  my @edges=map {$_->[0] le $_->[1]? $_: [$_->[1],$_->[0]]} @_;
  sort {$a->[0] cmp $b->[0] || $a->[1] cmp $b->[1]} @edges;
}
sub _edge_str {
  my($graph,$edge)=@_;
  my($v0,$v1)=@$edge;
  $v0 le $v1? "$v0 - $v1": "$v1 - $v0";
}
# checks (1) schema graph is tree; (2) all IdTypes covered
sub check_schema {
  my $self=shift;
  my $schema_graph=$self->schema_graph;
  # check for tree
  my @errstrs;
  unless ($schema_graph->is_connected) {
    my @components=$schema_graph->connected_components;
    push(@errstrs,"schema graph is not connected. connected components are (one per line)\n".
	 join("\n",map {join(' ',@$_)} @components));
  }
  if ($schema_graph->is_cyclic) {
    push(@errstrs,"schema graph is cyclic. one cycle is\n".join(' ',$schema_graph->find_a_cycle));
  }
  # check for uncovered IdTypes
  if (my @absent_idtypes=grep {!$schema_graph->has_vertex($_->id)} @{$self->idtypes}) {
    push(@errstrs,"following IdTypes not contained in any MapTables: ".
	 join(' ',map {$_->name} @absent_idtypes));
  }
  wantarray? @errstrs: (@errstrs? 0: 1);
}
sub check_contents {confess "check_contents NOT YET IMPLEMENTED"};

# traverse query (or schema graph), returning maptable nodes in any pre-order traversal
# can be called as function or method. $root is a maptable or master
my %seen;
sub traverse {
  my($root,$graph)=ref($_[0]) && $_[0]->isa('Graph')? @_[0,1]: @_[1,2];
  %seen=($root=>$root);
  _traverse($root,$graph);
}
sub _traverse {
  my($root,$graph)=@_;
  my @idtypes=map {$seen{$_}=$_} grep {!$seen{$_}} $graph->neighbors($root);
  my @maptables=map {$seen{$_}=$_} grep {!$seen{$_}} map {$graph->neighbors($_)} @idtypes;
  my @order=($root,map {_traverse($_,$graph)} @maptables);
  @order;
}

sub _name2object {
  my($self,$xxx)=(shift,shift);
  my $key="name2$xxx";
  unless ($self->{$key}) {           # not yet initialized. do it now
    my $component_attr="${xxx}s";    # component attributes are plural - end in 's'
    my $objects=$self->$component_attr;
    $self->{$key}={map {$_->name=>$_} @$objects};
  }
  if (@_==0) {			  # return entire HASH if no args
    return $self->{$key};
  } elsif (@_==1 && !ref $_[0]) { # return 1 value
    return $self->{$key}->{$_[0]};
  } elsif (@_==1 && ref $_[0]) {  # hopefully arg is an object. extract name and set value
    return $self->{$key}->{$_[0]->name}=$_[0];
  } elsif (@_==2) {	          # set name=>value
    return $self->{$key}->{$_[0]}=$_[1];
  } else {
    confess "Invalid arguments to name2$xxx";
  }
}

# _2idtype used in generate_query
sub _2idtype {
  my $self=shift;
  if (ref $_[0]) {
    confess "Invalid idtype $_[0]" unless $_[0]->isa('Data::Babel::IdType');
    return $_[0];
  }
  # else may be name or stringified ref
  unless ($_[0]=~/^Data::Babel::IdType=HASH\(0x\w+\)$/) {
    my $idtype=$self->name2idtype($_[0]);
    confess "Invalid idtype $_[0]" unless ref($idtype) && $idtype->isa('Data::Babel::IdType');
    return $idtype;
  }
  # code to convert stringified ref adapted from http://stackoverflow.com/questions/1671281/how-can-i-convert-the-stringified-version-of-array-reference-to-actual-array-ref?rq=1
  # CAUTION: will segfault if bad string passed in!
  require B;
  my($hexaddr)=$_[0]=~/.*(0x\w+)/;
  my $idtype=bless(\(0+hex $hexaddr), "B::AV")->object_2svref;
  confess "Invalid filter idtype $_[0]" unless $idtype=~/^Data::Babel::IdType=HASH\(0x\w+\)$/;
  $idtype;
}
# _2idtype_name NOT USED
# sub _2idtype_name {
#   my $self=shift;
#   if (ref $_[0]) {
#     confess "Invalid idtype $_[0]" unless UNIVERSAL::isa($_[0],'Data::Babel::IdType');
#     return $_[0]->name;
#   }
#   # else may be name or stringified ref
#   unless ($_[0]=~/^Data::Babel::IdType=HASH\(0x\w+\)$/) {
#     my $idtype=$self->name2idtype($_[0]);
#     confess "Invalid idtype $_[0]" unless UNIVERSAL::isa($idtype,'Data::Babel::IdType');
#     return $_[0];
#   }
#   # code to convert stringified ref adapted from http://stackoverflow.com/questions/1671281/how-can-i-convert-the-stringified-version-of-array-reference-to-actual-array-ref?rq=1
#   # CAUTION: will segfault if bad string passed in!
#   require B;
#   my($hexaddr)=$_[0]=~/.*(0x\w+)/;
#   my $idtype=bless(\(0+hex $hexaddr), "B::AV")->object_2svref;
#   confess "Invalid filter idtype $_[0]" unless $idtype=~/^Data::Babel::IdType=HASH\(0x\w+\)$/;
#   $idtype->name;
# }

# TODO: belongs in some Util
sub flatten {map {'ARRAY' eq ref $_? @$_: $_} @_;}

# NG 10-08-08. sigh.'verbose' in Class::AutoClass::Root conflicts with method in Base
#              because AutoDB splices itself onto front of @ISA.
sub verbose {Data::Babel::Base::verbose(@_)}
1;

__END__

=head1 NAME

Data::Babel - Translator for biological identifiers

=head1 VERSION

Version 1.11

=head1 SYNOPSIS

  use Data::Babel;
  use Data::Babel::Config;
  use Class::AutoDB;
  use DBI;

  # open database containing Babel metadata
  my $autodb=new Class::AutoDB(database=>'test');

  # try to get existing Babel from database
  my $babel=old Data::Babel(name=>'test',autodb=>$autodb);
  unless ($babel) {              
    # Babel does not yet exist, so we'll create it
    # idtypes, masters, maptables are names of configuration files that define 
    #   the Babel's component objects
    $babel=new Data::Babel
      (name=>'test',idtypes=>'examples/idtype.ini',masters=>'examples/master.ini',
       maptables=>'examples/maptable.ini');
  }
  # open database containing real data
  my $dbh=DBI->connect("dbi:mysql:database=test",undef,undef);

  # CAUTION: rest of SYNOPSIS assumes you've loaded the real database somehow
  # translate several Entrez Gene ids to other types
  my $table=$babel->translate
    (input_idtype=>'gene_entrez',
     input_ids=>[1,2,3],
     output_idtypes=>[qw(gene_symbol gene_ensembl chip_affy probe_affy)]);
  # print a few columns from each row of result
  for my $row (@$table) {
    print "Entrez gene=$row->[0]\tsymbol=$row->[1]\tEnsembl gene=$row->[2]\n";
  }
  # same translation but limit results to Affy hgu133a
  my $table=$babel->translate
    (input_idtype=>'gene_entrez',
     input_ids=>[1,2,3],
     filters=>{chip_affy=>'hgu133a'},
     output_idtypes=>[qw(gene_symbol gene_ensembl chip_affy probe_affy)]);
  # generate a table mapping all Entrez Gene ids to UniProt ids
  my $table=$babel->translate
    (input_idtype=>'gene_entrez',
     output_idtypes=>[qw(protein_uniprot)]);
  # convert to HASH for easy programmatic lookups
  my %gene2uniprot=map {$_[0]=>$_[1]} @$table;
  
  # count number of Entrez Gene ids represented on Affy hgu133a
  my $count=$babel->count
    (input_idtype=>'gene_entrez',filters=>{chip_affy=>'hgu133a'});

  # tell which input ids are valid
  my $table=$babel->validate
    (input_idtype=>'gene_entrez',
     input_ids=>[1,2,3]);
  # print validity status of each
  for my $row (@$table) {
    my($input_id,$valid,$current_id)=@$row;
    print "Entrez gene $input_id is ",
          ($valid? "valid with current value $current_id": 'invalid'),"\n";
  }

=head1 DESCRIPTION

Data::Babel translates biological identifiers based on information
contained in a database. Each Data::Babel object provides a unique
mapping over a set of identifier types. The system as a whole can
contain multiple Data::Babel objects; these may share some or all
identifier types, and may provide the same or different mappings over
the shared types.

The principal method is 'translate' which converts identifiers of one
type into identifiers of one or more output types.  In typical usage,
you call 'translate' with a list of input ids to convert.  You can
also call it without any input ids (or with the special option
'input_ids_all' set) to generate a complete mapping of the input type
to the output types.  This is convenient if you want to hang onto the
mapping for repeated use.  You can also filter the output based on
values of other identifier types.

CAVEAT: Some features of Data::Babel are overly specific to the
procedure we use to construct the underlying Babel database.  We note
such cases when they arise in the documentation below.

The main components of a Data::Babel object are

=over 2

=item 1. a list of Data::Babel::IdType objects, each representing a type of identifier 

=item 2. a list of Data::Babel::Master objects, one per IdType, providing

=over 2

=item * a master list of valid values for the type, and 

=item * optionally, a history mapping old values to current ones

=back

=item 3. a list of Data::Babel::MapTable objects which implement the mapping

=back

One typically defines these components using configuration files whose
basic format is defined in L<Config::IniFiles>. See examples in
L<Configuration files> and the examples directory of the distribution.

Each MapTable represents a relational table stored in the database and
provides a mapping over a subset of the Babel's IdTypes; the ensemble
of MapTables must, of course, cover all the IdTypes.  The ensemble of
MapTables must also be non-redundant as explained in L<Technical
details>.

MapTables must always contain current identifiers, even for IdTypes
that have histories (more precisely, for IdTypes whose Masters have
histories). The query or program that loads the database is
responsible for mapping old identifiers to current ones (presumably
via the history).

'translate' checks the input IdType to see if its Master has history
information. If so, 'translate' automatically applies the history to
all input ids.  It does the same for filters.

You need not explicitly define Masters for all IdTypes; Babel
will create 'implicit' Masters for any IdTypes lacking explicit
ones. An implicit Master has a list of valid identifiers but no
history and could be implemented as a view over all MapTables
containing the IdType. In the current implementation, we use views for
IdTypes contained in single MapTables but construct actual tables for
IdTypes contained in multiple MapTables.

=head2 Configuration files

Our configuration files use 'ini' format as described in
L<Config::IniFiles>: 'ini' format files consist of a number of
sections, each preceded with the section name in square brackets,
followed by parameter names and their values.

There are separate config files for IdTypes, Masters, and MapTables.
There are complete example files in the distribution. Here are some
excerpts:

IdType

  [chip_affy]
  display_name=Affymetrix array
  referent=array
  defdb=affy
  meta=name
  format=/^[a-z]+\d+/
  sql_type=VARCHAR(32)

The section name is the IdType name. The parameters are

=over 2

=item * display_name. human readable name for this type

=item * referent. the type of things to which this type of identifier refers

=item * defdb. the database, if any, responsible for assigning this type of identifier

=item * meta. some identifiers are purely synthetic (eg, Entrez gene IDs) while others have some mnemonic content; legal values are 

=over 2

=item * eid (meaning synthetic)  

=item * symbol

=item * name

=item * description

=back

=item * format. Perl format of valid identifiers

=item * sql_type.  SQL data type

=back

Master

  [gene_entrez_master]
  inputs=<<INPUTS
  MainData/GeneInformation
  INPUTS
  query=<<QUERY
  SELECT locus_link_eid AS gene_entrez FROM gene_information 
  QUERY

The section name is the Master name; the name of the IdType is the
same but without the '_master'. The 'inputs' and 'query' parameters
are used by our database construction procedure and may not be useful
in other settings.

The next example illustrates a Master that includes history information.

  [gene_entrez_master]
  inputs=<<INPUTS
  MainData/GeneInformation MainData/GeneHistory
  INPUTS
  query=<<QUERY
  SELECT old_locus_link_eid AS _ANY_gene_entrez, locus_link_eid AS gene_entrez
  FROM gene_information LEFT OUTER JOIN gene_history 
    ON locus_link_eid=new_locus_link_eid
  QUERY
  history=1

A Master without history is implemented as a one column table whose
column has the same name as the IdType.

A Master with history is implemented as a two column table: one column
has the same name as the IdType and the other has the prefix '_X_'
prepended to the IdType. The '_X_' column contains ids that were valid
in the past or are valid now. Each row maps the '_X_' id to its
current value, if any, or NULL. For ids that are valid now, the table
contains a row in which the '_X_' and current versions are the same.

MapTable

  [gene_entrez_information]
  inputs=MainData/GeneInformation 
  idtypes=gene_entrez gene_symbol gene_description organism_name_common
  query=<<QUERY
  SELECT 
         GENE.locus_link_eid AS gene_entrez, 
         GENE.symbol AS gene_symbol, 
         GENE.description AS gene_description,
         ORG.common_name AS organism_name_common
  FROM 
         gene_information AS GENE
         LEFT OUTER JOIN
         organism AS ORG ON GENE.organism_id=ORG.organism_id
  QUERY

  [% maptable %]
  inputs=MainData/GeneUnigene
  idtypes=gene_entrez gene_unigene
  query=<<QUERY
  SELECT UG.locus_link_eid AS gene_entrez, UG.unigene_eid AS gene_unigene
  FROM   gene_unigene AS UG
  QUERY

This excerpt has two MapTable definitions which illustrate two ways
that MapTables can be named.  The first uses a normal section name;
the second invokes a L<Template Toolkit|Template> macro which generates unique
names of the form 'maptable_001'.  This is very convenient because
Babel databases typically contain a large number of MapTables, and
it's hard to come up with good names for most of them.  In any case,
the names don't matter much, because software generates the queries
that operate on these tables.

The 'inputs' and 'query' parameters are used by our database
construction procedure and may not be useful in other settings.

=head2 Input ids that do not connect to any outputs

By default, the 'translate' method does not return any output for
input identifiers that do not connect to any identifiers of the
desired output types; these are output rows in which the output
columns are all NULL. You can instruct 'translate' to include these
rows in the result by setting the 'validate' option.

An input identifier can fail to connect for two reasons: 

=over 2

=item 1. The identifier is not valid, in other words, it does not
exist in the Master table for the input IdType.

=item 2. The identifier is valid but doesn't doesn't connect to any
ids of the desired output types. This is normal.

=back

If you set the 'validate' option, the output will contain at least one
row for each input identifier, and an additional column that indicates
whether each input identifier is valid.

If no output IdTypes are specified, 'translate' returns a row
containing one element, namely, the input identifier, for each input
id that exists in the corresponding Master table. If the 'validate'
option is set, the output will contain one row for each input
identifier; this is essentially a (possibly re-ordered) copy of the
input list with duplicates removed.

=head2 Technical details

A basic Babel property is that translations are stable. You can add
output types to a query without changing the answer for the types
you had before, you can remove output types from the query without
changing the answer for the ones that remain, and if you "reverse
direction" and swap the input type with one of the outputs, you get
everything that was in the original answer.

We accomplish this by requiring that the database of MapTables satisfy
the B<universal relation property> (a well-known concept in relational
database theory), and that 'translate' retrieves a sub-table of the
universal relational.  Concretely, the universal relational is the
natural full outer join of all the MapTables.  'translate' performs
natural left out joins starting with the Master table for the input
IdType, and then including enough tables to connect the input and
output IdTypes. Left outer joins suffice, because 'translate' starts
with the Master.

We further require that the database of MapTables be
non-redundant. The basic idea is that a given IdType may not be
present in multiple MapTables, unless it is being used as join column.
More technically, we require that the MapTables form a tree schema
(another well-known concept in relational database theory), and any
pair of MapTables have at most one IdType in common.  As a
consequence, there is essentially a single path between any pair of
IdTypes.

To represent the connections between IdTypes and MapTables we use an
undirected graph whose nodes represent IdTypes and MapTables, and
whose edges go between each MapTable and the IdTypes it contains. In
this representation, a non-redundant schema is a tree.

'translate' uses this graph to find the MapTables it must join to
connect the input and output IdTypes. The algorithms is simple: start
at the leaves and recursively prune back branches that do not contain
the input or output IdTypes.

=head1 METHODS AND FUNCTIONS

=head2 new

 Title   : new 
 Usage   : $babel=new Data::Babel
                      name=>$name,
                      idtypes=>$idtypes,masters=>$masters,maptables=>$maptables 
 Function: Create new Data::Babel object or fetch existing object from database
           and update its components.  Store the new or updated object.
 Returns : Data::Babel object
 Args    : name        eg, 'test'
           idtypes, masters, maptables
                       define component objects; see below
           old         existing Data::Babel object in case program already
                       fetched it (typically via 'old')
           autodb      Class::AutoDB object for database containing Babel.
                       class method often set before running 'new'
 Notes   : 'name' is required. All other args are optional

The component object parameters can be any of the following:

=over 2

=item 1. filenames referring to configuration files that define the
component objects

=item 2. any other file descriptors that can be handled by the new
method of L<Config::IniFiles>, eg, filehandles and IO::File objects

=item 3. objects of the appropriate type for each component, namely,
Data::Babel::IdType, Data::Babel::Master, Data::Babel::MapTable,
respectively

=item 4. ARRAYs of the above

=back

=head2 old

 Title   : old 
 Usage   : $babel=old Data::Babel($name)
           -- OR --
           $babel=old Data::Babel(name=>$name)
 Function: Fetch existing Data::Babel object from database          
 Returns : Data::Babel object or undef
 Args    : name of Data::Babel object, eg, 'test'
           if keyword form used, can also specify autodb to set the
           corresponding class attribute

=head2 attributes

The available object attributes are

  name       eg, 'test' 
  id         name prefixed with 'babel', eg, 'babel:test'. not really used.  
             exists for compatibility with component objects
  idtypes    ARRAY of this Babel's Data::Babel::IdType objects
  masters    ARRAY of this Babel's Data::Babel::Master objects
  maptables  ARRAY of this Babel's Data::Babel::MapTable objects

The available class attributes are

  autodb     Class::AutoDB object for database containing Babel

=head2 translate

 Title   : translate 
 Usage   : $table=$babel->translate
                     (input_idtype=>'gene_entrez',
                      input_ids=>[1,2,3],
                      filters=>{chip_affy=>'hgu133a'},
                      output_idtypes=>[qw(transcript_refseq transcript_ensembl)],
                      limit=>100)
 Function: Translate the input ids to ids of the output types
 Returns : table represented as an ARRAY of ARRAYS. Each inner ARRAY is one row
           of the result. The first element of each row is an input id. If the
           validate option is set, the second element of each row indicates
           whether the input id is valid. The rest are outputs in the same order
           as output_idtypes
 Args    : input_idtype   name of Data::Babel::IdType object or object
           input_ids      id or ARRAY of ids to be translated. If absent or
                          undef, all ids of the input type are translated. If an
                          empty array, ie, [], no ids are translated and the 
                          result will be empty.
           input_ids_all  boolean. If true, all ids of the input type are
                          translated. Same as omitting input_ids or setting it
                          to undef but more explicit.
           filters        HASH or ARRAY of conditions limiting the output; see 
                          below.
           output_idtypes ARRAY of names of Data::Babel::IdType objects or
                          objects
           validate       boolean. If true, the output will contain at least one
                          row for each input id and an additional column 
                          indicating whether the input id is valid.
           limit          maximum number of rows to retrieve
           count          boolean. If true, return number of output rows rather 
                          than the rows themselves. Equivalent to 'count'
                          method.

=head3 Notes on translate

=over 2

=item * 'translate' retains duplicate output columns.

=item * The order of output rows is arbitrary.

=item * If input_ids is absent or undef, it translates all ids of the
input type.

=item * Duplicate input_ids are ignored.

=item * If input_ids is an empty ARRAY, ie, [], the result will be
empty.

=item * It is an error to set both input_ids and input_ids_all.

=item * It is legal but odd to specify a filter on the input
idtype. This effectively computes the intersection of the input and
filter ids.

=item * Input and filter ids can be old (valid in the past) or current
(valid now). Output ids are always current.

=item * By default, 'translate' does not return rows in which the
output columns are all NULL. Setting 'validate' changes this and
ensures that every input id will appear in the output.

=item * If 'count' and 'limit' both set, the result is the number of
output rows after the limit is applied and will always be <= the
limit.

=item * If 'validate' and 'limit' both set, the result may not contain
all input ids if to do so would produce more rows than the limit. This
defeats one of the purposes of 'validate', namely to ensure that all
input ids appear in the output.

=item * If 'count' and 'validate' both set, the result is the number
of output rows including ones added by 'validate', ie, rows with in
which all output columns are NULL.

=item * If 'validate' and 'filters' both set, the result may contain
input ids excluded by the filter. These rows will have NULLs in all
output columns.

=item * If no output idtypes are specified, the output will contain
one row for each valid input id (by default) or one row for each id
whether valid or not (if 'validate' is set). 

=back

=head3 Filters

The 'filters' argument is a HASH or ARRAY of types and values. The
types can be names of Data::Babel::IdType objects or objects
themselves. The values can be single ids, ARRAYs of ids, or undef; the
ARRAYs may also contain undef. For example

  filters=>{chip_affy=>'hgu133a'}
  filters=>{chip_affy=>['hgu133a','hgu133plus2']}
  filters=>{chip_affy=>['hgu133a','hgu133plus2'],pathway_kegg_id=>4610}
  filters=>{chip_affy=>['hgu133a','hgu133plus2'],pathway_kegg_id=>undef}
  filters=>{chip_affy=>'hgu133a',pathway_kegg_id=>[undef,4610]}

If the argument is an ARRAY, it is possible for the same type to
appear multiple times in which case the values are combined.  For example,

  filters=>[chip_affy=>'hgu133a',chip_affy=>'hgu133plus2']

is equivalent to 

  filters=>{chip_affy=>['hgu133a','hgu133plus2']}

If a filter value is an empty ARRAY, ie, [], the result will be empty.

If a filter value is undef, all ids of the given type are acceptable.
This limits the output to rows for which the filter type is not
NULL. For example,

  $babel->translate(input_idtype=>'gene_entrez',
                    filters=>{pathway_kegg_id=>undef},
                    output_idtypes=>[qw(gene_symbol)])

generates a table of all Entrez Gene ids and gene symbols which appear in
any KEGG pathway.

Including undef in an ARRAY lets the output contain rows for which the
filter type is NULL.  For example,

  $babel->translate(input_idtype=>'gene_entrez',
                    filters=>{pathway_kegg_id=>[undef,4610]},
                    output_idtypes=>[qw(gene_symbol)])

generates a table of all Entrez Gene ids and gene symbols which either
appear in KEGG pathway 4610 or appear in no KEGG pathway.

CAUTION: undef has opposite semantics depending on whether it's the
only value for a filter type or whether it's one of several.

=head3 Histories

'translate' automatically applies histories, when they exist, to input
and filter ids. In other words, input and filter ids can be ones that
were valid in the past but are not valid now. Output ids, however, are
always current.

CAUTION: If the input type is also used as an output, the result can
contain rows in which the output id does not equal the input id. This
will occur if the input id is old and is mapped to a different current
value.  Likewise, if a filter type is used as an output, the result
can contain rows in which the output id does not match the filter.

=head2 count

 Title   : count 
 Usage   : $number=$babel->count
                     (input_idtype=>'gene_entrez',
                      input_ids=>[1,2,3],
                      filters=>{chip_affy=>'hgu133a'},
                      output_idtypes=>[qw(transcript_refseq transcript_ensembl)])
 Function: Count number of output rows that would be generated by 'translate'
 Returns : number
 Args    : same as 'translate'

'count' is a wrapper for L<translate> that sets the 'count' argument to a true value.

=head2 validate

 Title   : validate 
 Usage   : $table=$babel->validate
                     (input_idtype=>'gene_entrez',
                      input_ids=>[1,2,3])
 Function: Tell which input ids are valid now or in the past, and the mapping 
           from old to current values
 Returns : table represented as an ARRAY of ARRAYS. Each inner ARRAY is one row
           of the result. If output_idtypes is omiited (the usual case), the 
           elements of each row are
             0) input id as given
             1) validity status. 1 for valid; 0 for invalid
             2) current value of the id or undef if it has no current value; may
                be the same as the original id
           If output_idtypes is set, the result is ther same as 'translate' with
           the 'validate' option set
 Args    : input_idtype   name of Data::Babel::IdType object or object
           input_ids      id or ARRAY of ids to be translated. If absent or
                          undef, all ids of the input type are translated. If an
                          empty array, ie, [], no ids are translated and the 
                          result will be empty.
           input_ids_all  boolean. If true, all ids of the input type are
                          translated. Same as omitting input_ids or setting it
                          to undef but more explicit.
           output_idtypes optional and usually omitted. ARRAY of names of 
                          Data::Babel::IdType objects or objects. If set,
                          equivalent to calling 'translate' with the 'validate'
                          option set
           limit          maximum number of rows to retrieve

'validate' looks up the given input ids in the Master tables for the
given input type and returns a table indicating which ids are
valid. For types with history information, the method also
indicates the current value of the id. For types that have no history,
the current value will always equal the given id if the id is valid.

'validate' can also retrieve a complete table of valid ids (along with
history information) for the type.

'validate' is a wrapper for L<translate> that sets the 'validate'
argument to a true value and the output_idtypes argument to the
input_idtype.  All other 'translate' arguments (filters, count) are
legal here and work but are of dubious value.

=head3 Notes on validate

=over 2

=item * For rows whose validity status is 1 (valid), the given id and
current value indicate the history: if the elements are equal, the
given id is current; else if the current value is defined, the given
id has been replaced by the new one; else the given id was valid in
the past but has no current value.

=item * For types that have no history, all valid ids are current. If
the given id is valid, the given id and current value will be equal;
else the current value will be undef.

=item * For rows whose status is 0 (invalid), the current value will
always be undef.

=item * The 'translate' arguments 'filters' and 'count' are legal here
and work but are of dubious value.

=back

=head2 show

 Title   : show
 Usage   : $babel->show
 Function: Print object in readable form
 Returns : nothing useful
 Args    : none

=head2 check_schema

 Title   : check_schema
 Usage   : @errstrs=$babel->check_schema
           -- OR --
           $ok=$babel->check_schema
 Function: Validate schema. Presently checks that schema graph is tree and all
           IdTypes contained in some MapTable
 Returns : in array context, list of errors
           in scalar context, true if schema is good, false if schema is bad
 Args    : none

=head2 check_contents - NOT YET IMPLEMENTED

 Title   : check_contents
 Usage   : $babel->check_schema
 Function: Validate contents of Babel database. Checks consistency of explicit
           Masters and MapTables
 Returns : boolean
 Args    : none

=head2 load_implicit_masters

 Title   : load_implicit_masters
 Usage   : $babel->load_implicit_masters
 Function: Creates database structures for implicit Masters. 
 Returns : nothing useful
 Args    : none

Babel creates 'implicit' Masters for any IdTypes lacking explicit
ones. An implicit Master has a list of valid identifiers and could be
implemented as a view over all MapTables containing the IdType. In the
current implementation, we use views for IdTypes contained in single
MapTables but construct actual tables for IdTypes contained in
multiple MapTables. 

This method must be called after the real database is loaded.

=head2 Finding component objects by name or id & related

Objects have names and ids: names are strings like 'gene_entrez' and
are unique for a given class of object; ids have a short form of the
type prepended to the name, eg, 'idtype:gene_entrez', and are unique
across all classes. We use ids as nodes in schema and query graphs. In
most cases, applications should should use names.

The methods in this section map names or ids to component objects, or
(as a trivial convenience), convert ids to names.

=head3 name2idtype

 Title   : name2idtype
 Usage   : $idtype=$babel->name2idtype('gene_entrez')
 Function: Get the IdType object given its name
 Returns : Data::Babel::IdType object or undef
 Args    : name of object
 Notes   : only looks at this Babel's component objects

=head3 name2master

 Title   : name2master
 Usage   : $master=$babel->name2master('gene_entrez_master')
 Function: Get the Master object given its name
 Returns : Data::Babel::Master object or undef
 Args    : name of object
 Notes   : only looks at this Babel's component objects

=head3 name2maptable

 Title   : name2maptable
 Usage   : $maptable=$babel->name2maptable('maptable_012')
 Function: Get the MapTable object given its name
 Returns : Data::Babel::MapTable object or undef
 Args    : name of object
 Notes   : only looks at this Babel's component objects

=head3 id2object

 Title   : id2object
 Usage   : $object=$babel->id2object('idtype:gene_entrez')
 Function: Get object given its id
 Returns : Data::Babel::IdType, Data::Babel::Master, Data::Babel::MapTable
           object or undef
 Args    : id of object
 Notes   : only looks at this Babel's component objects

=head3 id2name

 Title   : id2name
 Usage   : $name=$babel->id2name('idtype:gene_entrez')
           -- OR --
           $name=Data::Babel->id2name('idtype:gene_entrez')
 Function: Convert object id to name
 Returns : string
 Args    : id of object
 Notes   : trival convenience method

=head1 METHODS AND ATTRIBUTES OF COMPONENT CLASS Data::Babel::IdType

=head2 new

 Title   : new 
 Usage   : $idtype=new Data::Babel::IdType name=>$name,...
 Function: Create new Data::Babel::IdType object or fetch existing object from 
           database and update its components. Store the new or updated object.
 Returns : Data::Babel::IdType object
 Args    : any attributes listed in the attributes section below, except 'id'
           (because it is computed from name)
           old         existing Data::Babel object in case program already
                       fetched it (typically via 'old')
           autodb      Class::AutoDB object for database containing Babel.
                       class method often set before running 'new'
 Notes   : 'name' is required. All other args are optional

=head2 old

 Title   : old 
 Usage   : $idtype=old Data::Babel::IdType($name)
           -- OR --
           $babel=old Data::Babel::IdType(name=>$name)
 Function: Fetch existing Data::Babel::IdType object from database          
 Returns : Data::Babel::IdType object or undef
 Args    : name of Data::Babel::IdType object, eg, 'gene_entrez'
           if keyword form used, can also specify autodb to set the
           corresponding class attribute

=head2 attributes

The available object attributes are

  name          eg, 'gene_entrez' 
  id            name prefixed with 'idtype', eg, 'idtype:::gene_entrez'
  master        Data::Babel::Master object for this IdType
  maptables     ARRAY of Data::Babel::MapTable objects containing this IdType
  external      boolean indicating whether this is a regular external ID or one
                intended for internal use
  internal      opposite of external
  history       boolean indicating whether this IdType's Master contains history
                information
  tablename     name of this IdType's Master's table
  display_name  human readable name, eg, 'Entrez Gene ID'; for internal 
                identifiers, a warning is appended to the end
  referent      the type of things to which this type of identifier refers
  defdb         the database, if any, which assigns identifiers
  meta          meta-type: eid (meaning synthetic), symbol, name, description
  format        Perl format of valid identifiers, eg, /^\d+$/
  perl_format   synonym for format
  sql_type      SQL data type, eg, INT(11)

The available class attributes are

  autodb     Class::AutoDB object for database containing Babel

=head2 degree

 Title   : degree 
 Usage   : $number=$idtype->degree
 Function: Tell how many Data::Babel::MapTables contain this IdType          
 Returns : number
 Args    : none

=head1 METHODS AND ATTRIBUTES OF COMPONENT CLASS Data::Babel::Master

=head2 new

 Title   : new 
 Usage   : $master=new Data::Babel::Master name=>$name,idtype=>$idtype,...
 Function: Create new Data::Babel::Master object or fetch existing object from 
           database and update its components. Store the new or updated object.
 Returns : Data::Babel::Master object
 Args    : any attributes listed in the attributes section below, except 'id'
           (because it is computed from name)
           old         existing Data::Babel object in case program already
                       fetched it (typically via 'old')
           autodb      Class::AutoDB object for database containing Babel.
                       class method often set before running 'new'
 Notes   : 'name' is required. All other args are optional

=head2 old

 Title   : old 
 Usage   : $master=old Data::Babel::Master($name)
           -- OR --
           $babel=old Data::Babel::Master(name=>$name)
 Function: Fetch existing Data::Babel::Master object from database          
 Returns : Data::Babel::Master object or undef
 Args    : name of Data::Babel::Master object, eg, 'gene_entrez'
           if keyword form used, can also specify autodb to set the
           corresponding class attribute

=head2 attributes

The available object attributes are

  name          eg, 'gene_entrez_master' 
  id            name prefixed with 'master::', eg, 'master:::gene_entrez_master'
  idtype        Data::Babel::IdType object for which this is the Master
  implicit      boolean indicating whether Master is implicit
  explicit      opposite of implicit
  view          boolean indicating whether Master is implemented as a view
  history       boolean indicating whether Master contains history information.
  tablename     synonym for name
  inputs, namespace, query
                used by our database construction procedure

The available class attributes are

  autodb     Class::AutoDB object for database containing Babel

=head2 degree

 Title   : degree 
 Usage   : $number=$master->degree
 Function: Tell how many Data::Babel::MapTables contain this Master's IdType          
 Returns : number
 Args    : none

=head1 METHODS AND ATTRIBUTES OF COMPONENT CLASS Data::Babel::MapTable

=head2 new

 Title   : new 
 Usage   : $maptable=new Data::Babel::MapTable name=>$name,idtypes=>$idtypes,...
 Function: Create new Data::Babel::MapTable object or fetch existing object from 
           database and update its components. Store the new or updated object.
 Returns : Data::Babel::MapTable object
 Args    : any attributes listed in the attributes section below, except 'id'
           (because it is computed from name)
           old         existing Data::Babel object in case program already
                       fetched it (typically via 'old')
           autodb      Class::AutoDB object for database containing Babel.
                       class method often set before running 'new'
 Notes   : 'name' is required. All other args are optional

=head2 old

 Title   : old 
 Usage   : $maptable=old Data::Babel::MapTable($name)
           -- OR --
           $babel=old Data::Babel::MapTable(name=>$name)
 Function: Fetch existing Data::Babel::MapTable object from database          
 Returns : Data::Babel::MapTable object or undef
 Args    : name of Data::Babel::MapTable object, eg, 'gene_entrez'
           if keyword form used, can also specify autodb to set the
           corresponding class attribute

=head2 attributes

The available object attributes are

  name          eg, 'gene_entrez_master' 
  id            name prefixed with 'maptable', eg, 'maptable:::gene_entrez_master'
  idtypes       ARRAY of Data::Babel::IdType objects contained by this MapTable
  inputs, namespace, query
                used by our database construction procedure

The available class attributes are

  autodb     Class::AutoDB object for database containing Babel

=head1 SEE ALSO

I'm not aware of anything.

=head1 AUTHOR

Nat Goodman, C<< <natg at shore.net> >>

=head1 BUGS AND CAVEATS

Please report any bugs or feature requests to C<bug-data-babel at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-Babel>.  I will
be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head2 Known Bugs and Caveats

=over 2

=item 1. The attributes of Master and MapTable objects are overly
specific to the procedure we use to construct databases and may not be
useful in other settings.

=item 2. This class uses L<Class::AutoDB> to store its metadata and
inherits all the L<Known Bugs and Caveats|Class::AutoDB/"Known Bugs
and Caveats"> of that module.

=back

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::Babel

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-Babel>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Data-Babel>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Data-Babel>

=item * Search CPAN

L<http://search.cpan.org/dist/Data-Babel/>

=back

=head1 ACKNOWLEDGEMENTS

This module extends a version developed by Victor Cassen.

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Institute for Systems Biology

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

