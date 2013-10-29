package Data::Babel::Filter;
#################################################################################
#
# Author:	Nat Goodman
# Created:	13-09-17
# $Id$
#
# Copyright 2013 Institute for Systems Biology
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either: the GNU General Public License as published
# by the Free Software Foundation; or the Artistic License.
#
# See http://dev.perl.org/licenses/ for more information.
#
# Represents a condition limiting the output of a 'translate' query
# Does the heavy lifting for translate's support of filters
# Concretely, wraps a SQL expression that can be used as a WHERE clause
# (but without the 'WHERE') or ANDed onto a WHERE clause (but without
# the 'AND') in a query generated by translate
# 
#################################################################################
use strict;
use Carp;
use List::Categorize qw(categorize);
use List::MoreUtils qw(any uniq);
use Scalar::Util qw(blessed);
use Text::Balanced qw(extract_delimited extract_multiple);

use base qw(Class::AutoClass);
use vars qw(@AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS);
@AUTO_ATTRIBUTES=qw(babel sql conditions filter_idtype filter_idtypes 
		    prepend_idtype allow_sql embedded_idtype_marker);
@OTHER_ATTRIBUTES=qw(treat_string_as treat_stringref_as);
%DEFAULTS=(filter_idtypes=>[],prepend_idtype=>'auto',allow_sql=>1,embedded_idtype_marker=>':');
%SYNONYMS=();
Class::AutoClass::declare;
# choices for indicator attributes
our @treat_string_as=qw(id sql);
our @treat_stringref_as=qw(sql id);
# categories of conditions
#  empty is empty array
our @cats=qw(undef empty id object sql array);

sub _init_self {
  my ($self,$class,$args) = @_;
  return unless $class eq __PACKAGE__;
  return unless defined $self->babel; # can't do anything without babel
  # TODO: entire implementation!!
  $self->fix_idtypes;
  my $sql=$self->generate_sql;	# do the work!
  $self->sql($sql);
  $self->filter_idtypes([uniq(@{$self->filter_idtypes})]);
}
# make sure all idtypes valid, replace names by objects, move filter_idtype into filter_idtypes
sub fix_idtypes {
  my $self=shift;
  my @filter_idtypes=map {$self->_fix_idtype($_)} @{$self->filter_idtypes};
  if (defined(my $filter_idtype=$self->filter_idtype)) {
    $filter_idtype=$self->filter_idtype($self->_fix_idtype($filter_idtype));
    unshift(@filter_idtypes,$filter_idtype);
  }
  $self->filter_idtypes(\@filter_idtypes);
}
sub _fix_idtype {
  my($self,$idtype)=@_;
  return $idtype if blessed($idtype) && $idtype->isa('Data::Babel::IdType');
  confess "Invalid reference $idtype passed os IdType" if ref $idtype;
  return $self->babel->name2idtype($idtype) || confess "Invalid IdType name $idtype";
}
sub generate_sql {
  my $self=shift;
  my($conditions)=$self->conditions;
  my $cat=$self->cat($conditions);
  return $self->gen_empty() if $cat eq 'empty';
  return $self->gen_notnull() if $cat eq 'undef';
  return $self->gen_id($conditions) if $cat eq 'id';
  return $self->gen_object($conditions) if $cat eq 'object';
  return $self->gen_sql($conditions) if $cat eq 'sql';
  # ARRAY
  my @sql;
  my %cats=categorize {$self->cat($_)} @$conditions;
  push(@sql,$self->gen_empty()) if defined $cats{empty} && @{$cats{empty}};
  push(@sql,$self->gen_null()) if defined $cats{undef} && @{$cats{undef}};
  push(@sql,$self->gen_id(@{$cats{id}})) if defined $cats{id} && @{$cats{id}};
  push(@sql,$self->gen_object(@{$cats{object}})) if defined $cats{object} && @{$cats{object}};
  push(@sql,$self->gen_sql(@{$cats{sql}})) if defined $cats{sql} && @{$cats{sql}};
  @sql=uniq @sql;
  my $sql=@sql==1? $sql[0]: join(' OR ',map {"($_)"} @sql);
  $sql;
}
# categorize conditions or elements of conditions ARRAY
sub cat {
  my($self,$conditions)=@_;
  return 'empty' if 'ARRAY' eq ref $conditions && !@$conditions;
  return 'undef' if !defined $conditions;
  return 'object' if blessed($conditions) && $conditions->isa(__PACKAGE__);
  return 'id' if 
    (!ref $conditions && $self->treat_string_as eq 'id') || 
      ('SCALAR' eq ref $conditions && $self->treat_stringref_as eq 'id');
   return 'sql' if 
     (!ref $conditions && $self->treat_string_as eq 'sql') || 
       ('SCALAR' eq ref $conditions && $self->treat_stringref_as eq 'sql');
  return 'array' if 'ARRAY' eq ref $conditions && @$conditions;
  confess "Invalid conditions $conditions";
}
sub gen_empty {'FALSE'}
sub gen_notnull {
  my $self=shift;
  my $filter_idtype=$self->filter_idtype;
  confess "filter_idtype must be set when conditions is undef" unless defined $filter_idtype;
  my $colname=_generate_colname($filter_idtype);
  "$colname IS NOT NULL";
}
sub gen_null {
  my $self=shift;
  my $filter_idtype=$self->filter_idtype;
  confess "filter_idtype must be set when conditions is undef" unless defined $filter_idtype;
  my $colname=_generate_colname($filter_idtype);
  "$colname IS NULL";
}
sub gen_object {
  my $self=shift;
  my @sql=map {$_->sql} @_;
  @_==1? $sql[0]: @sql;
}
sub gen_id {
  my $self=shift;
  return unless @_;
  my $filter_idtype=$self->filter_idtype;
  confess "filter_idtype must be set when conditions is id" unless defined $filter_idtype;
  my $colname=_generate_colname($filter_idtype);
  my @qids=map {$self->quote($_)} uniq map {ref $_? ${$_}: $_} @_;
  my $sql=@qids==1? "$colname = $qids[0]": "$colname IN (".join(',',@qids).')';
  $sql;
}
sub gen_sql {
  my $self=shift;
  return unless @_;
  confess "Cannot accept SQL fragment unless allow_sql is true" unless $self->allow_sql;
  my @fragments=map {ref $_? ${$_}: $_} @_;
  my @sql;
  my($filter_idtype,$prepend_idtype,$embedded_idtype_marker)=
    $self->get(qw(filter_idtype prepend_idtype embedded_idtype_marker));
  my $colname=_generate_colname($filter_idtype);
  for my $fragment (@fragments) {
    $fragment=~s/^\s+||\s+$//g;	# strip leading and trailing whitespace
    # NG 13-10-17: empty SQL means FALSE
    # next unless length $fragment;
    push(@sql,'FALSE'),next unless length $fragment;
    if ($fragment!~/\Q$embedded_idtype_marker\E/) {
      # easy case - $fragment has no embedded_idtype_marker
      # prepend_idtype if allowed, and possible
      if ($prepend_idtype) {
	confess "Cannot prepend idtype to SQL fragment unless filter_idtype is set" 
	  unless defined $filter_idtype;
	push(@sql,"$colname $fragment");
      } else {
	push(@sql,$fragment);
      }
    } else {
      # general case - $fragment has embedded_idtype_marker. may be in constant, though
      # extract quoted strings and embedded idtypes
      my @parts=extract_multiple
	($fragment,
	 [{Quote=>sub {extract_delimited($_[0],q{'"})}},
	  {IdType=>qr/(\Q$embedded_idtype_marker\E\w+)|(\Q$embedded_idtype_marker\E)/},
	 ]);
      # check for unmatched quotes
      map {confess "Unmatched quote in SQL fragment $_" if !ref($_) && /["']/} @parts;
      # check that filter_idtype set if default embedded idtype used
      confess "Cannot use default embedded idtype in SQL fragment unless filter_idtype is set"
	if (any {'IdType' eq ref($_) && ${$_} eq $embedded_idtype_marker} @parts) && 
	  !defined $filter_idtype;
      # prepend_idtype if necessary, allowed, and possible
      my $prepend;
      if ($prepend_idtype eq 'auto') {
	$prepend=1 if !ref $parts[0]; # fragment starts with naked SQL
      } else {
	$prepend=$prepend_idtype;
      }
      if ($prepend) {
	confess "Cannot prepend idtype to SQL fragment unless filter_idtype is set" 
	  unless defined $filter_idtype;
	unshift(@parts,$colname);
      }
      # good to go!
      for my $part (@parts) {
	if ('IdType' eq ref $part) {
	  $$part=$colname, next if $$part eq $embedded_idtype_marker;
	  my($idtype)=$$part=~/\Q$embedded_idtype_marker\E(.*)/;
	  $idtype=$self->babel->name2idtype($idtype) || confess "Invalid IdType name $idtype";
	  push(@{$self->filter_idtypes},$idtype);
	  $$part=_generate_colname($idtype);
	} elsif (!ref $part) {
	  # $part=~s/^\s+||\s+$//g;	# strip leading and trailing whitespace
	  $part=~s/^(\w)/ \1/; 	        # prepend space if word first
	  $part=~s/(\w)$/\1 /; 	        # append space if word last
	}
      }
      # push(@sql,join(' ',map {ref $_? ${$_}: $_} @parts));
      my $sql=join('',map {ref $_? ${$_}: $_} @parts);
      $sql=~s/^\s+||\s+$//g;	# strip leading and trailing whitespace
      push(@sql,$sql);
    }
  }
  @_==1? $sql[0]: @sql;
}
sub _generate_colname {
  my $idtype=shift;
  return undef unless defined $idtype;
  !$idtype->history? $idtype->name: '_X_'.$idtype->name;
}

# indicator attributes
sub indicator {
  my($self,$attribute)=(shift,shift);
  my @choices=eval '@'.$attribute or
    confess "Trying to access unknown indicator attribute $attribute";
  unless (@_) {
    return defined $self->{$attribute}? $self->{$attribute}: ($self->{$attribute}=$choices[0]);
  }
  # setting new value
  my $value=shift;
  return $self->{$attribute}=$choices[0] unless defined $value;
  confess("Invalid value $value for attribute $attribute: valid choices are ".
	  join(', ',@choices)) unless grep /^$value$/i,@choices;
  return $self->{$attribute}=lc $value;
}
sub treat_string_as {shift->indicator('treat_string_as',@_)}
sub treat_stringref_as {shift->indicator('treat_stringref_as',@_)}
# sub prepend_idtype_to {shift->indicator('prepend_idtype_to',@_)}

# convenience methods
sub dbh {shift->babel->dbh}
sub quote {shift->babel->dbh->quote(@_)}

# NG 10-08-08. sigh.'verbose' in Class::AutoClass::Root conflicts with method in Base
#              because AutoDB splices itself onto front of @ISA.
sub verbose {Data::Babel::Base::verbose(@_)}
1;