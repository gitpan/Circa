package Circa;

# module Circa: provide general method for Circa
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.

# $Log: Circa.pm,v $
# Revision 1.5  2001/06/02 08:18:26  alian
# - Add self parameter to appartient method
#
# Revision 1.4  2001/05/28 18:41:18  alian
# - Move Parser method from Circa.pm to Indexer.pm
#
# Revision 1.3  2001/05/22 23:28:09  alian
# - Remove load of Circa::Parser
# - Add POD Documentation
#
# Revision 1.2  2001/05/21 22:51:01  alian
# - Add field for export and import routine
# - Add Pod documentation
#
# Revision 1.1  2001/05/21 18:47:24  alian
# - Cumul des fonctions utilisées dans l'indexeur et le searcher
#
#

use DBI;
use DBI::DBD;
use Circa::Categorie;
use Circa::Url;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw();
$VERSION = ('$Revision: 1.5 $ ' =~ /(\d+\.\d+)/)[0];

#------------------------------------------------------------------------------
# new
#------------------------------------------------------------------------------
sub new 
  {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->{DBH} = undef;
    $self->{PREFIX_TABLE} = 'circa_';
    $self->{SERVER_PORT}  ="3306";   # Port de mysql par default
    #$self->{DEBUG} = 1;
    return $self;
  }

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub port_mysql
  {
  my $self = shift;
  if (@_) {$self->{SERVER_PORT}=shift;}
  return $self->{SERVER_PORT};
  }

#------------------------------------------------------------------------------
# pre_tbl
#------------------------------------------------------------------------------
sub pre_tbl
  {
  my $self = shift;
  if (@_) {$self->{PREFIX_TABLE}=shift;}
  return $self->{PREFIX_TABLE};
  }

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub connect
  {
  my ($this,$user,$password,$db,$server)=@_;
  my $driver = "DBI:mysql:database=$db;host=$server;port=".$this->port_mysql;
  $this->{_DB}=$db; $this->{_PASSWORD}=$password; $this->{_USER}=$user;
  $this->{DBH} = DBI->connect($driver,$user,$password,{ PrintError => 0 }) 
    || return 0;
  return 1;
  }

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub close {$_[0]->{DBH}->disconnect;}

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub dbh { return $_[0]->{DBH};}

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub categorie {return new Circa::Categorie($_[0]);}

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub URL {return new Circa::Url($_[0]);}

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub start_classic_html
  { 
    my ($self,$cgi)=@_;
    return $cgi->start_html(
    -'title'  => 'Circa',
    -'author'  => 'alian@alianwebserver.com',
    -'meta'    => {'keywords'=>'circa,recherche,annuaire,moteur',
          -'copyright'  => 'copyright 1997-2000 AlianWebServer'},
    -'style'  => {'src'=>"circa.css"},
    -'dtd'    => '-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd')."\n";
  }



#------------------------------------------------------------------------------
# header
#------------------------------------------------------------------------------
sub header {return "Content-Type: text/html\n\n";}


#------------------------------------------------------------------------------
# fill_template
#------------------------------------------------------------------------------
sub fill_template
  {
  my ($self,$masque,$vars)=@_;
  open(FILE,$masque) || die "Can't read $masque<br>";
  my @buf=<FILE>;
  CORE::close(FILE);
  while (my ($n,$v)=each(%$vars))
    {
    if ($v) {map {s/<\? \$$n \?>/$v/gm} @buf;}
    else {map {s/<\? \$$n \?>//gm} @buf;}
    }
  return join('',@buf);
  }

#------------------------------------------------------------------------------
# fetch_first
#------------------------------------------------------------------------------
sub fetch_first
  {
  my ($self,$requete)=@_;
  my $sth = $self->{DBH}->prepare($requete);
  $sth->execute || print STDERR "Erreur:$requete:$DBI::errstr<br>";
  # Pour chaque categorie
  my @row = $sth->fetchrow_array;
  $sth->finish;
  if (wantarray()) { return @row; }
  else { return $row[0]; }
  }

#------------------------------------------------------------------------------
# appartient
#------------------------------------------------------------------------------
sub appartient
  {
  my ($self,$elem,@liste)=@_;
  foreach (@liste) {return 1 if ($_ and $_ eq $elem);}
  return 0;
  }


#------------------------------------------------------------------------------
# POD DOCUMENTATION
#------------------------------------------------------------------------------

=head1 NAME

Circa - a Search Engine/Indexer running with Mysql

=head1 DESCRIPTION

This is Circa::Search, a module who provide functions to
perform search on Circa, a www search engine running with
Mysql. Circa is for your Web site, or for a list of sites.
It indexes like Altavista does. It can read, add and
parse all url's found in a page. It add url and word
to MySQL for use it at search.

Circa can be used for index 100 to 100 000 url

Notes:

=over

=item *

Accents are removed on search and when indexed

=item *

Search are case unsensitive (mmmh what my english ? ;-)

=back

Circa::Search work with Circa::Indexer result. Circa::Search is a Perl 
interface, but it's exist on this package a PHP client too.

=head1 SYNOPSIS

See L<Circa::Search>, L<Circa::Indexer>

=head1 SEE ALSO

L<Circa::Indexer> : Indexer module

L<Circa::Search> : Searcher module

L<Circa::Url> : Manage url of Circa

L<Circa::Categorie> : Manage categorie of Circa

L<Circa::Parser> : Manage Parser of Circa

=head1 Public interface

You use this method behind Circa::Indexer and Circa::Search object

=over

=item connect($user,$password,$db)

Connect Circa to MySQL. Return 1 on succes, 0 else

=over

=item *

$user     : Utilisateur MySQL

=item *

$password : Mot de passe MySQL

=item *

$db       : Database MySQL

=item *

$server   : Adr IP du serveur MySQL

=back

Connect Circa to MySQL. Return 1 on succes, 0 else

=item close

Close connection to MySQL

=item pre_tbl

Get or set the prefix for table name for use Circa with more than one
time on a same database

=item fill_template($masque,$vars)

 $masque : Path of template
 $vars : hash ref with keys/val to substitue

Give template with remplaced variables
Ex: if $$vars{age}=12, and $masque have

  J'ai <? $age ?> ans,

this function give:

  J'ai 12 ans,

=back

=head1 AUTHOR

Alain BARBET alian@alianwebserver.com

=cut

1;
