package t::utilBabel;
use t::util;
use Carp;
use Test::More;
use Test::Deep;
use List::MoreUtils qw(uniq);
use Exporter();
our @ISA=qw(Exporter);

our @EXPORT=
  (@t::util::EXPORT,
   qw(check_object_basics sort_objects
      prep_tabledata load_maptable load_master load_ur select_ur cleanup_ur
      cmp_objects cmp_objects_quietly cmp_table cmp_table_quietly
      check_handcrafted_idtypes check_handcrafted_masters check_handcrafted_maptables
      check_handcrafted_name2idtype check_handcrafted_name2master check_handcrafted_name2maptable
      check_handcrafted_id2object check_handcrafted_id2name
      load_handcrafted_maptables load_handcrafted_masters
    ));

sub check_object_basics {
  my($object,$class,$name,$label)=@_;
  report_fail($object,"$label connected object defined") or return 0;
  $object->name;		# touch object in case still Oid
  report_fail(UNIVERSAL::isa($object,$class),"$label: class") or return 0;
  report_fail($object->name eq $name,"$label: name") or return 0;
  return 1;
}
sub check_objects_basics {
  my($objects,$class,$names,$label)=@_;
  my @objects=sort_objects($objects,$label);
  for my $i (0..$#$objects) {
    my $object=$objects->[$i];
    check_object_basics($objects->[$i],$class,$names->[$i],"$label object $i") or return 0;
  }
  return 1;
}
# sort by name.
sub sort_objects {
  my($objects,$label)=@_;
  # hmm.. this doesn't work for Oids. not important anyway, so just bag it
  # TODO: revisit when AutoDB provides public method for fetching Oids.
#   # make sure all objects have names
#   for my $i (0..$#$objects) {
#     my $object=$objects->[$i];
#     report_fail(UNIVERSAL::can($object,'name'),"$label object $i: has name method") 
#       or return ();
#   }
  my @sorted_objects=sort {$a->name cmp $b->name} @$objects;
  wantarray? @sorted_objects: \@sorted_objects;
}
# scrunch whitespace
sub scrunch {
  my($x)=@_;
  $x=~s/\s+/ /g;
  $x=~s/^\s+|\s+$//g;
  $x;
}
sub scrunched_eq {scrunch($_[0]) eq scrunch($_[1]);}

########################################
# these functions deal w/ relational tables

# prepare table data
# data can be 
#   string: one line per row; each row is whitespace-separated values
#   list or ARRAY of strings: each string is row
#   list or ARRAY of ARRAYs: each sub-ARRAY is row
# CAUTION: 2nd & 3rd cases ambiguous: list of 1 ARRAY could fit either case!
sub prep_tabledata {
  # NG 12-08-24: fixed to handle list or ARRAY of ARRAYs as documented
  # my @rows=(@_==1 && !ref $_[0])? split(/\n+/,$_[0]): flatten(@_);
  my @rows=(@_==1 && !ref $_[0])? split(/\n+/,$_[0]): (@_==1)? flatten(@_): @_;
  # clean whitespace and split rows 
  @rows=map {ref($_)? $_: do {s/^\s+|\s+$//g; s/\s+/ /g; [split(' ',$_)]}} @rows;
  # convert NULLS into undefs
  for my $row (@rows) {
    map {$_=undef if 'NULL' eq uc($_)} @$row;
  }
  \@rows;
}
sub load_maptable {
  my($babel,$maptable)=splice(@_,0,2);
  my $data=prep_tabledata(@_);
  ref $maptable or $maptable=$babel->name2maptable($maptable);

  # code adapted from ConnectDots::LoadMapTable Step
  my $tablename=$maptable->tablename;
  my @idtypes=@{$maptable->idtypes};
  my @column_names=map {$_->name} @idtypes;
  my @column_sql_types=map {$_->sql_type} @idtypes;
  my @column_defs=map {$column_names[$_].' '.$column_sql_types[$_]} (0..$#idtypes);
  my @indexes=@column_names;

  # code adapted from MainData::LoadData Step
  my $dbh=$babel->autodb->dbh;
  $dbh->do(qq(DROP TABLE IF EXISTS $tablename));
  my $columns=join(', ',@column_defs);
  $dbh->do(qq(CREATE TABLE $tablename ($columns)));

  # new code: insert data into table
  my @values=map {'('.join(', ',map {$dbh->quote($_)} @$_).')'} @$data;
  my $values=join(",\n",@values);
  $dbh->do(qq(INSERT INTO $tablename VALUES\n$values));

  # code adapted from MainData::LoadData Step
  # put parens around single columns
  my @alters=map {"($_)"} @indexes; # put parens around single columns
  my $alters=join(', ',map {"ADD INDEX $_"} @alters);
  $dbh->do(qq(ALTER TABLE $tablename $alters));
}
sub load_master {
  my($babel,$master)=splice(@_,0,2);
  my $data=prep_tabledata(@_);
  ref $master or $master=$babel->name2master($master);

  # code adapted from ConnectDots::LoadMaster, ConnectDots::LoadImpMaster, MainData::LoadData
  my $tablename=$master->tablename;
  my $idtype=$master->idtype;
  my $column_name=$idtype->name;
  my $column_sql_type=$idtype->sql_type;
  my $column_def="$column_name $column_sql_type";
  my $query=$master->query;

  my $dbh=$babel->autodb->dbh;
  # NG 12-08-24: moved DROPs out conditionals since master could be table in one babel
  #              and view in another
  $dbh->do(qq(DROP VIEW IF EXISTS $tablename));
  $dbh->do(qq(DROP TABLE IF EXISTS $tablename));
 if ($master->view) {
    $dbh->do(qq(CREATE VIEW $tablename AS\n$query));
    return;
  }
  my $sql=qq(CREATE TABLE $tablename ($column_def));
  $sql.=" AS\n$query" if $master->implicit; # if implicit, load data via query
  $dbh->do($sql);
  if (!$master->implicit) {
    # new code: insert data into table
    my @values=map {'('.join(', ',map {$dbh->quote($_)} @$_).')'} @$data;
    my $values=join(",\n",@values);
    $dbh->do(qq(INSERT INTO $tablename VALUES\n$values));
  }
  # code adapted from MainData::LoadData Step
  $dbh->do(qq(ALTER TABLE $tablename ADD INDEX ($column_name)));
}
# create universal relation (UR)
# algorithm: natual full outer join of all maptables and explicit masters
#            any pre-order traversal of schema graph will work (I think!)
# >>> assume that lexical order of maptables gives a valid pre-order <<<
# sadly, since MyQSL still lacks full outer joins, have to emulate with left/right
# joins plus union. do it step-by-step: I couldn't figure out how to do it in
# one SQL statement...
sub load_ur {
  my($babel,$urname)=@_;
  $urname or $urname='ur';
  # ASSUME that lexical order of maptables gives a valid pre-order
  my @tables=sort {$a->tablename cmp $b->tablename} @{$babel->maptables};
  # add in explicit Masters. order doesn't matter so long as they're last
  push(@tables,grep {$_->explicit} @{$babel->masters});

  my $left=shift @tables;
  while (my $right=shift @tables) {
    my $result_name=@tables? undef: $urname; # final answer is 'ur'
    $left=full_join($babel,$left,$right,$result_name);
  }
  $left;
}
# NG 11-01-21: added 'translate all'
# NG 12-08-22: added 'filters'
# select data from ur (will actually work for any table)
sub select_ur {
  my $args=new Hash::AutoHash::Args(@_);
  my($babel,$urname,$input_idtype,$input_ids,$input_ids_all,$output_idtypes,$filters)=
    @$args{qw(babel urname input_idtype input_ids input_ids_all output_idtypes filters)};
  confess "Only one of inputs_ids or input_ids_all may be set" if $input_ids && $input_ids_all;
  $urname or $urname=$args->tablename || 'ur';
  my $input_idtype=ref $input_idtype? $input_idtype->name: $input_idtype;
  my @output_idtypes=map {ref $_? $_->name: $_} @$output_idtypes;
  my @filter_idtypes=map {ref $_? $_->name: $_} keys %$filters;

  my $dbh=$babel->autodb->dbh;
  # NG 10-08-25: removed 'uniq' since duplicate columns are supposed to be kept
  # my @columns=uniq grep {length($_)} ($input_idtype,@output_idtypes);
  my @columns=grep {length($_)} ($input_idtype,@output_idtypes);
  my $columns=join(', ',@columns);
  my $sql=qq(SELECT DISTINCT $columns FROM $urname);
  my @wheres;
  if ($input_ids) {
    my $cond=@$input_ids? 
      "$input_idtype IN ".'('.join(', ',map {$dbh->quote($_)} @$input_ids).')': 'FALSE';
    push(@wheres,$cond);
  }
  for my $filter_idtype (@filter_idtypes) {
    my $filter_ids=$filters->{$filter_idtype};
    my @filter_ids=ref $filter_ids? @$filter_ids: $filter_ids;
    my $cond=@filter_ids? 
      "$filter_idtype IN ".'('.join(', ',map {$dbh->quote($_)} @filter_ids).')': 'FALSE';
    push(@wheres,$cond);
  }
  $sql.=' WHERE '.join(' AND ',@wheres) if @wheres;
  my $result=$dbh->selectall_arrayref($sql);
  # NG 10-11-10: remove NULL rows, because translate now skips these
  if (@output_idtypes) {
    my @result;
    for my $row (@$result) {
      my @output_cols=$input_idtype? @$row[1..$#$row]: @$row;
      push(@result,$row) if grep {defined $_} @output_cols;
    }
    $result=\@result;
  }
  # NG 11-01-21: if input_ids_all set, exclude rows where input_idtype is NULL
  #   (the check for $input_idtype is for consistency with loop above. I don't know
  #    whether it's possible for input_ids_all to be set w/o input_idtype being set)
  # NG 12-08-22: changed test for input_ids_all to !$input_ids - more general
  if ($input_idtype && !$input_ids) {
    my @result=grep {defined $_->[0]} @$result;
    $result=\@result;
  }
  $result;
}
# cmp ARRAYs of Babel component objects (anything with an 'id' method will work)
# like cmp_bag but 
# 1) reports errors the way we want them
# 2) sorts the args to avoid Test::Deep's 'bag' which is ridiculously slow...
sub cmp_objects {
  my($actual,$correct,$label,$file,$line,$limit)=@_;
  my $ok=cmp_objects_quietly($actual,$correct,$label,$file,$line,$limit);
  report_pass($ok,$label);
}
sub cmp_objects_quietly {
  my($actual,$correct,$label,$file,$line)=@_;
  my @actual_sorted=sort {$a->id cmp $b->id} @$actual;
  my @correct_sorted=sort  {$a->id cmp $b->id} @$correct;
  cmp_quietly(\@actual_sorted,\@correct_sorted,$label,$file,$line);
}
# like cmp_bag but 
# 1) reports errors the way we want them
# 2) sorts the args to avoid Test::Deep's 'bag' which is ridiculously slow...
# NG 10-11-08: extend to test limit. CAUTION: limit should be small or TOO SLOW!
sub cmp_table {
  my($actual,$correct,$label,$file,$line,$limit)=@_;
  my $ok=cmp_table_quietly($actual,$correct,$label,$file,$line,$limit);
  report_pass($ok,$label);
}
sub cmp_table_quietly {
  my($actual,$correct,$label,$file,$line,$limit)=@_;
  unless (defined $limit) {
    my @actual_sorted=sort cmp_rows @$actual;
    my @correct_sorted=sort cmp_rows @$correct;
    # my $ok=cmp_quietly($actual,bag(@$correct),$label,$file,$line);
    return cmp_quietly(\@actual_sorted,\@correct_sorted,$label,$file,$line);
  } else {
    report_fail(@$actual<=$limit,"$label: expected $limit row(s), got ".scalar @$actual,
		$file,$line)
      or return 0;
    return cmp_quietly($actual,subbagof(@$correct),$label,$file,$line);
  }
  $ok;
}

# sort subroutine: $a, $b are ARRAYs of strings. should be same lengths. cmp element by element
sub cmp_rows {
  my $ret;
  for (0..$#$a) {
    return $ret if $ret=$a->[$_] cmp $b->[$_];
  }
  # equal up to here. if $b has more, then $a is smaller
  $#$a <=> $#$b;
}
# emulate natural full outer join. return result table
# $result is optional name of result table. if not set, unique name generated
# TODO: add option to delete intermediate tables as we go.
sub full_join {
  my($babel,$left,$right,$result_name)=@_;
  my @idtypes=uniq(@{$left->idtypes},@{$right->idtypes});
  my $result=new t::FullOuterJoinTable(name=>$result_name,idtypes=>\@idtypes);
  my $leftname=$left->tablename;
  my $rightname=$right->tablename;
  my $resultname=$result->tablename;
  my @column_names=map {$_->name} @idtypes;
  my @column_sql_types=map {$_->sql_type} @idtypes;
  my @column_defs=map {$column_names[$_].' '.$column_sql_types[$_]} (0..$#idtypes);
  my $column_names=join(', ',@column_names);
  my $column_defs=join(', ',@column_defs);
  
  # code adapted from MainData::LoadData Step
  my $dbh=$babel->autodb->dbh;
  $dbh->do(qq(DROP TABLE IF EXISTS $resultname));
  my $columns=join(', ',@column_defs);
  my $query=qq
    (SELECT $column_names FROM $leftname NATURAL LEFT OUTER JOIN $rightname
     UNION
     SELECT $column_names FROM $leftname NATURAL RIGHT OUTER JOIN $rightname);
  $dbh->do(qq(CREATE TABLE $resultname ($columns) AS\n$query));
  $result;
}
# arg is babel. clean up intermediate tables created en route to ur
sub cleanup_ur {t::FullOuterJoinTable->cleanup(@_) }

########################################
# these functions test our hand-crafted Babel & components

sub check_handcrafted_idtypes {
  my($actual,$mature,$label)=@_;
  $label or $label='idtypes'.($mature? ' (mature)': '');
  my $num=4;
  my $class='Data::Babel::IdType';
  report_fail(@$actual==$num,"$label: number of elements") or return 0;
  my @actual=sort_objects($actual,$label) or return 0;
  for my $i (0..$#actual) {
    my $actual=$actual[$i];
    my $suffix='00'.($i+1);
    report_fail(UNIVERSAL::isa($actual,$class),"$label object $i: class") or return 0;
    report_fail($actual->name eq "type_$suffix","$label object $i: name") or return 0;
    report_fail($actual->id eq "idtype:type_$suffix","$label object $i: id") or return 0;
    report_fail($actual->display_name eq "display_name_$suffix","$label object $i: display_name") or return 0;
    report_fail($actual->referent eq "referent_$suffix","$label object $i: referent") or return 0;
    report_fail($actual->defdb eq "defdb_$suffix","$label object $i: defdb") or return 0;
    report_fail($actual->meta eq "meta_$suffix","$label object $i: meta") or return 0;
    report_fail($actual->format eq "format_$suffix","$label object $i: format") or return 0;
    report_fail($actual->sql_type eq "VARCHAR(255)","$label object $i: sql_type") or return 0;
    if ($mature) {
      check_object_basics($actual->babel,'Data::Babel','test',"$label object $i babel");
      check_object_basics($actual->master,'Data::Babel::Master',
			  "type_${suffix}_master","$label object $i master");
    }
  }
  pass($label);
}

# masters 2&3 are implicit, hence some of their content is special
# NG 10-11-10: implicit Masters now have clauses to exclude NULLs in their queries
sub check_handcrafted_masters {
  my($actual,$mature,$label)=@_;
  $label or $label='masters'.($mature? ' (mature)': '');
  my $num=$mature? 4: 2;
  my $class='Data::Babel::Master';
  report_fail(@$actual==$num,"$label: number of elements") or return 0;
  my @actual=sort_objects($actual,$label) or return 0;
  for my $i (0..$#actual) {
    my $actual=$actual[$i];
    my $suffix='00'.($i+1);
    my $name="type_${suffix}_master";
    my $id="master:$name";
    # masters 2&3 are implicit, hence some of their content is special
    my($inputs,$namespace,$query,$view,$implicit);
    if ($i<2) {
      $inputs="MainData/table_$suffix";
      $namespace="ConnectDots";
      $namespace="ConnectDots";
      $query="SELECT col_$suffix AS type_$suffix FROM table_$suffix";
      $view=0;
      $implicit=0;
    } else {
      $namespace='';		# namespace not in input config file, but hopefully set in output
      $implicit=1;
      if ($i==2) {
	$inputs="ConnectDots/maptable_003 ConnectDots/maptable_002";
	# NG 10-11-10: added clause to exclude NULLs
# 	$query=<<QUERY
# 	SELECT type_003 FROM maptable_003
# 	UNION
# 	SELECT type_003 FROM maptable_002
# QUERY
	$query=<<QUERY
	SELECT type_003 FROM maptable_003 WHERE type_003 IS NOT NULL
	UNION
	SELECT type_003 FROM maptable_002 WHERE type_003 IS NOT NULL
QUERY
  ;
	$view=0;
      } elsif ($i==3) {
	$inputs="ConnectDots/maptable_003";
	# NG 10-11-10: added clause to exclude NULLs
	# $query="SELECT DISTINCT type_004 FROM maptable_003";
	$query="SELECT DISTINCT type_004 FROM maptable_003 WHERE type_004 IS NOT NULL";
	$view=1;      
      }}

    report_fail(UNIVERSAL::isa($actual,$class),"$label object $i: class") or return 0;
    report_fail($actual->name eq $name,"$label object $i: name") or return 0;
    report_fail($actual->id eq $id,"$label object $i: id") or return 0;
    report_fail(scrunched_eq($actual->inputs,$inputs),"$label object $i: inputs") or return 0;
    report_fail(scrunched_eq($actual->namespace,$namespace),"$label object $i: namespace") or return 0;
    report_fail(scrunched_eq($actual->query,$query),"$label object $i: query") or return 0;
    report_fail(as_bool($actual->view)==$view,"$label object $i: view") or return 0;
    report_fail(as_bool($actual->implicit)==$implicit,"$label object $i: implicit") or return 0;
    if ($mature) {
      check_object_basics($actual->babel,'Data::Babel','test',"$label object $i babel");
      check_object_basics($actual->idtype,'Data::Babel::IdType',
			  "type_$suffix","$label object $i idtype");
    }
  }
  pass($label);
}

sub check_handcrafted_maptables {
  my($actual,$mature,$label)=@_;
  $label or $label='maptables'.($mature? ' (mature)': '');
  my $num=3;
  my $class='Data::Babel::MapTable';
  report_fail(@$actual==$num,"$label: number of elements") or return 0;
  my @actual=sort_objects($actual,$label) or return 0;
  for my $i (0..$#actual) {
    my $actual=$actual[$i];
    my $suffix='00'.($i+1);
    my $suffix1='00'.($i+2);
    my $name="maptable_$suffix";
    my $id="maptable:$name";
    my $inputs="MainData/table_$suffix";
    my $query=<<QUERY
SELECT col_$suffix AS type_$suffix, col_$suffix1 AS type_$suffix1
FROM   table_$suffix
QUERY
      ;
    report_fail(UNIVERSAL::isa($actual,$class),"$label object $i: class") or return 0;
    report_fail($actual->name eq $name,"$label object $i: name") or return 0;
    report_fail($actual->id eq $id,"$label object $i: id") or return 0;
    report_fail(scrunched_eq($actual->inputs,$inputs),"$label object $i: inputs") or return 0;
    report_fail(scrunched_eq($actual->namespace,"ConnectDots"),"$label object $i: namespace") or return 0;
    report_fail(scrunched_eq($actual->query,$query),"$label object $i: query") or return 0;
     if ($mature) {
      check_object_basics($actual->babel,'Data::Babel','test',"$label object $i babel");
      check_objects_basics($actual->idtypes,'Data::Babel::IdType',
			  ["type_$suffix","type_$suffix1"],"$label object $i idtypes");
    }
  }
  pass($label);
}

sub check_handcrafted_name2idtype {
  my($babel)=@_;
  my $label='name2idtype';
  my %name2idtype=map {$_->name=>$_} @{$babel->idtypes};
  for my $name (qw(type_001 type_002 type_003 type_004)) {
    my $actual=$babel->name2idtype($name);
    report_fail($actual==$name2idtype{$name},"$label: object $name") or return 0;
  }
  pass($label);
}
sub check_handcrafted_name2master {
  my($babel)=@_;
  my $label='name2master';
  my %name2master=map {$_->name=>$_} @{$babel->masters};
  for my $name (qw(type_001 type_002 type_003 type_004)) {
    my $actual=$babel->name2master($name);
    report_fail($actual==$name2master{$name},"$label: object $name") or return 0;
  }
  pass($label);
}
sub check_handcrafted_name2maptable {
  my($babel)=@_;
  my $label='name2maptable';
  my %name2maptable=map {$_->name=>$_} @{$babel->maptables};
  for my $name (qw(type_001 type_002 type_003 type_004)) {
    my $actual=$babel->name2maptable($name);
    report_fail($actual==$name2maptable{$name},"$label: object $name") or return 0;
  }
  pass($label);
}
sub check_handcrafted_id2object {
  my($babel)=@_;
  my $label='id2object';
  my @objects=(@{$babel->idtypes},@{$babel->masters},@{$babel->maptables});
  my %id2object=map {$_->id=>$_} @objects;
  my @ids=
    (qw(idtype:type_001 idtype:type_002 idtype:type_003 idtype:type_004),
     qw(master:type_001_master master:type_002_master master:type_003_master master:type_004_master),
     qw(maptable:maptable_001 maptable:maptable_002 maptable:maptable_003));
  for my $id (@ids) {
    my $actual=$babel->id2object($id);
    report_fail($actual==$id2object{$id},"$label: object $id") or return 0;
  }
  pass($label);
}
sub check_handcrafted_id2name {
  my($babel)=@_;
  my $label='id2name';
  my @ids=
    (qw(idtype:type_001 idtype:type_002 idtype:type_003 idtype:type_004),
     qw(master:type_001_master master:type_002_master master:type_003_master master:type_004_master),
     qw(maptable:maptable_001 maptable:maptable_002 maptable:maptable_003));
  my @names=
    (qw(type_001 type_002 type_003 type_004),
     qw(type_001_master type_002_master type_003_master type_004_master),
     qw(maptable_001 maptable_002 maptable_003));
  my %id2name=map {$ids[$_]=>$names[$_]} (0..$#ids);
  for my $id (@ids) {
    my $actual=$babel->id2name($id);
    report_fail($actual eq $id2name{$id},"$label: object $name") or return 0;
  }
  pass($label);
}

sub load_handcrafted_maptables {
  my($babel,$data)=@_;
  for my $name (qw(maptable_001 maptable_002 maptable_003)) {
    load_maptable($babel,$name,$data->$name->data);
  }
}
sub load_handcrafted_masters {
  my($babel,$data)=@_;
  # explicit masters
  for my $name (qw(type_001_master type_002_master)) {
    load_master($babel,$name,$data->$name->data);
  }
  # implicit masters have no data
  for my $name (qw(type_003_master type_004_master)) {
    load_master($babel,$name);
  }
}
1;

package t::FullOuterJoinTable;
# simple class to represent intermediate tables used to emulate full outer joins
use strict;
use Carp;
use Class::AutoClass;
use vars qw(@AUTO_ATTRIBUTES @OTHER_ATTRIBUTES @CLASS_ATTRIBUTES %SYNONYMS %DEFAULTS);
use base qw(Class::AutoClass);

@AUTO_ATTRIBUTES=qw(name idtypes);
@OTHER_ATTRIBUTES=qw(seqnum);
@CLASS_ATTRIBUTES=qw();
%SYNONYMS=(tablename=>'name',columns=>'idtypes');
%DEFAULTS=(idtypes=>[]);
Class::AutoClass::declare;

our $seqnum=0;
sub seqnum {shift; @_? $seqnum=$_[0]: $seqnum}

sub _init_self {
  my($self,$class,$args)=@_;
  return unless $class eq __PACKAGE__; # to prevent subclasses from re-running this
  my $name=$self->name || $self->name('fulljoin_'.sprintf('%03d',++$seqnum));
}
# drop all tables that look like our intermediates
sub cleanup {
  my($class,$babel)=@_;
  my $dbh=defined $babel? $babel->autodb->dbh: Data::Babel->autodb->dbh;
  my @tables=@{$dbh->selectcol_arrayref(qq(SHOW TABLES LIKE 'fulljoin_%'))};
  # being a bit paranoid, make sure each table ends with 3 digits
  @tables=grep /\d\d\d$/,@tables;
  map {$dbh->do(qq(DROP TABLE IF EXISTS $_))} @tables;
}
1;
