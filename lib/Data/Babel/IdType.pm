package Data::Babel::IdType;
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
use Carp;
use Class::AutoClass;
use vars qw(@AUTO_ATTRIBUTES @OTHER_ATTRIBUTES @CLASS_ATTRIBUTES %SYNONYMS %DEFAULTS %AUTODB);
use base qw(Data::Babel::Base);

# babel, name, id, autodb, log, verbose - methods defined in Base
@AUTO_ATTRIBUTES=qw(master maptables referent defdb meta format sql_type internal);
@OTHER_ATTRIBUTES=qw(display_name external);
@CLASS_ATTRIBUTES=qw();
%SYNONYMS=(perl_format=>'format');
%DEFAULTS=(maptables=>[]);
%AUTODB=
  (-collection=>'IdType',
   -keys=>qq(name string,display_name string,referent string,defdb string,meta string,
             perl_format string,sql_type string,internal string));
   
Class::AutoClass::declare;

# must run after Babel initialized
sub connect_master {
  my $self=shift;
  my $master_name=$self->name.'_master'; # append '_master' to idtype name
  $self->{master}=$self->babel->name2master($master_name)
    or confess 'Trying to connect IdType '.$self->name.' to non-existent Master';
}
# must run after Babel initialized
sub add_maptable {push(@{shift->maptables},shift)}
# degree is number of MapTables containing this IdType
sub degree {scalar @{shift->maptables}}

our $WARN_INTERNAL=": FOR INTERNAL USE ONLY";
sub display_name {
  my $self=shift;
  my $display_name=@_? $self->{_display_name}=shift: $self->{_display_name};
  $self->internal? "$display_name$WARN_INTERNAL": $display_name;
}

# opposite of internal
sub external {
  my $self=shift;
  @_? !$self->internal(!$_[0]): !$self->internal;
}


# NG 10-08-08. sigh.'verbose' in Class::AutoClass::Root conflicts with method in Base
#              because AutoDB splices itself onto front of @ISA.
sub verbose {Data::Babel::Base::verbose(@_)}
1;
