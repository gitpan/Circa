package Circa::Categorie;

# module Circa::Categorie : See Circa::Indexer
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.

# $Log: Categorie.pm,v $
# Revision 1.7  2001/05/23 00:06:18  alian
# - Correct a bug in getParent
#
# Revision 1.6  2001/05/22 14:13:52  alian
# - Remove prefix_table call and replace it by $self->{INDEXER}->pre_tbl
#
# Revision 1.5  2001/05/21 22:37:43  alian
# - Add loadAll and getMasque method
#
# Revision 1.4  2001/05/20 12:18:20  alian
# - Change auto method to return a value not an array
#
# Revision 1.3  2001/05/14 23:26:52  alian
# - Correct some call to Circa::Indexer class
#
# Revision 1.2  2001/05/14 21:05:50  alian
# - Update POD documentation
#
# Revision 1.1  2001/05/14 14:59:02  alian
# - Code retiré de Indexer.pm
#
#

use strict;
use DBI;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw();
$VERSION = ('$Revision: 1.7 $ ' =~ /(\d+\.\d+)/)[0];


#------------------------------------------------------------------------------
# new
#------------------------------------------------------------------------------
sub new 
  {
    my $class = shift;
    my $self = {};
    my $indexer = shift;
    bless $self, $class;
    $self->{INDEXER} = $indexer;
    $self->{DBH} = $indexer->{DBH};
    return $self;
  }

#------------------------------------------------------------------------------
# set_masque
#------------------------------------------------------------------------------
sub set_masque
  {
  my ($this,$compte,$id,$file)=@_;
  $this->{DBH}->do("update ".$this->{INDEXER}->pre_tbl.$compte."categorie ".
		   "set masque='$file' where id = $id");
  }

#------------------------------------------------------------------------------
# get_masque
#------------------------------------------------------------------------------
sub get_masque
  {
  my ($this,$compte,$id,$file)=@_;
  return $this->{INDEXER}->fetch_first
    ("select masque from ".$this->{INDEXER}->pre_tbl.$compte."categorie ".
     "where id = $id");
  }
  
#------------------------------------------------------------------------------
# delete
#------------------------------------------------------------------------------
sub delete
  {
  my ($self,$compte,$id)=@_;
  my $pre = $self->{INDEXER}->pre_tbl.$compte;
  my $sth = $self->{DBH}->prepare("select id from ".$pre."links ".
				  "where categorie=$id");
   $sth->execute || print &header,"Erreur:delete_categorie:$DBI::errstr<br>";
  # Pour chaque categorie
  while (my @row = $sth->fetchrow_array)
    {$self->{DBH}->do("delete from ".$pre."relation where id_site = $row[0]");}
  $sth->finish;
  $self->{DBH}->do("delete from ".$pre."links where categorie = $id");
  $self->{DBH}->do("delete from ".$pre."categorie where id = $id");
  }

#------------------------------------------------------------------------------
# rename
#------------------------------------------------------------------------------
sub rename
  {
  my ($this,$compte,$id,$nom)=@_;
  $this->{DBH}->do("update ".$this->{INDEXER}->pre_tbl.$compte."categorie ".
		   "set nom='$nom' where id = $id") 
    || print STDERR "Erreur:$DBI::errstr<br>\n";
  }

#------------------------------------------------------------------------------
# move
#------------------------------------------------------------------------------
sub move
  {
  my ($this,$compte,$id1,$id2)=@_;
  $this->{DBH}->do("update ".$this->{INDEXER}->pre_tbl.$compte."links ".
		   "set categorie=$id2 where categorie = $id1")
    || print STDERR "Erreur:$DBI::errstr<br>\n";
  }

#------------------------------------------------------------------------------
# get_liste
#------------------------------------------------------------------------------
sub get_liste
  {
  my ($self,$id,$cgi)=@_;
  my (%tab,$tab2,$erreur);
  $tab2 = $self->loadAll($id);
  my $sth = $self->{DBH}->prepare("select count(1),categorie from ".
			       $self->{INDEXER}->pre_tbl.$id."links ".
			       "group by categorie");
  $sth->execute() || return;
  while (my @row=$sth->fetchrow_array) {$tab{$row[1]}=$row[0];}
  $sth->finish;
  if (!$$tab2{0}) {$$tab2{0}[0]='Racine';$$tab2{0}[1]=0;}
  foreach (keys %$tab2) 
    {$tab{$_}= $self->getParent($_,%$tab2)." (".($tab{$_}||0).")";}
  my @l =sort { $tab{$a} cmp $tab{$b} } keys %tab;
  return (\@l,\%tab);
  }

#------------------------------------------------------------------------------
# get
#------------------------------------------------------------------------------
sub get
  {
  my ($self,$rep,$responsable) = @_;
  my $ori = $self->{INDEXER}->host_indexed;
  $rep=~s/$ori//g;
  my @l = split(/\//,$rep);
  my $parent=0;
  my $regexp = qr/\.(htm|html|txt|java)$/;
  foreach (@l) 
    {
      if (($_) && ($_ !~ $regexp)) 
	{$parent = $self->create($_,$parent,$responsable);}
    }
  return $parent;
  }

#------------------------------------------------------------------------------
# create
#------------------------------------------------------------------------------
sub create
  {
  my ($self,$nom,$parent,$responsable)=@_;
  $nom=ucfirst($nom);
  $nom=~s/_/ /g;
  my $id;
  if ($nom) 
    {
      ($id) = $self->{INDEXER}->fetch_first
	("select id from ".$self->{INDEXER}->pre_tbl.$responsable."categorie ".
	 "where nom='$nom' and parent=$parent");
    }
  if ((!$id) && (defined $parent))
    {
    my $sth = $self->{DBH}->prepare("insert into ".
				    $self->{INDEXER}->pre_tbl.$responsable.
				    "categorie(nom,parent) ".
				    "values('$nom',$parent)");
    $sth->execute 
      || print STDERR "Erreur insert into ".
	$self->{INDEXER}->pre_tbl.$responsable."categorie(nom,parent) ".
	  "values('$nom',$parent) : $DBI::errstr<br>";
    $sth->finish;
    $id = $sth->{'mysql_insertid'};
    }
  return $id || 0;
  }

#------------------------------------------------------------------------------
# auto
#------------------------------------------------------------------------------
sub auto
  {
    my ($self,$idp) = @_;
    my @tab = $self->{INDEXER}->fetch_first
      ("select categorieAuto from ".$self->{INDEXER}->pre_tbl."responsable ".
       "where id=$idp");
    return $tab[0];
  }

#------------------------------------------------------------------------------
# loadAll
#------------------------------------------------------------------------------
sub loadAll
  {
  my ($self,$idr)=@_;
  my %tab;
  my $sth = $self->{DBH}->prepare
    ("select id,nom,parent from ".$self->{INDEXER}->pre_tbl.$idr."categorie");
  #print "requete:$requete\n";
  $sth->execute() || print "Erreur $DBI::errstr\n";
  while (my ($id,$nom,$parent)=$sth->fetchrow_array)
    {
    $tab{$id}[0]=$nom;
    $tab{$id}[1]=$parent;
    }
  return \%tab;
  }


#------------------------------------------------------------------------------
# getParent
#------------------------------------------------------------------------------
sub getParent
  {
  my ($self,$id,%tab)=@_;
  my $parent;
  if ($tab{$id}[1] and $tab{$id}[0])
    {$parent = $self->getParent($tab{$id}[1],%tab);}
  if (!$tab{$id}[0]) {$tab{$id}[0]='Home';}
  $parent.=">$tab{$id}[0]";
  return $parent;
  }

#------------------------------------------------------------------------------
# POD DOCUMENTATION
#------------------------------------------------------------------------------

=head1 NAME

Circa::Categorie - provide functions to manage categorie of Circa

=head1 SYNOPSIS

my $indexer = new Circa::Indexer;
# Delete categorie 2 for account 1
$indexer->categorie->delete(1,2);
...

=head1 DESCRIPTION

This module provide several function to manage categorie of Circa.

=head1 VERSION

$Revision: 1.7 $

=head1 Public Class Interface

=over

=item new($indexer_instance)

Create a new Circa::Categorie object with indexer instance properties

=item set_masque($compte,$id,$file)

Set a different masque ($file) for browse this categorie $id for account

=item get_masque($compte,$id)

Return path of masque for this categorie for account

=item delete($compte,$id)

Drop categorie $id for account $compte. (All url and words for this account)

Supprime la categorie $id pour le compte de responsable $compte et
tous les liens et relation qui sont dans cette categorie

=item rename($compte,$id,$nom)

Rename category $id for account $compte in $name

Renomme la categorie $id pour le compte $compte en $nom

=item move($compte,$id1,$id2)

Move url for account $compte from one categorie $id1 to another $id2

=item get_liste($id,$cgi)

Return two references to a list and a hash.
The hash have name of categorie as key, and number of site in this categorie 
as value. The list is ordered keys of hash.

=item get($rep,$responsable)

Return id of directory $rep. If directory didn't exist, function create it.

=item create($nom,$parent,$responsable)

Create categorie $nom with parent $parent for account $responsable

=item auto($idp)

Return 1 if account $idp want auto categorie. 0 else.

=item loadAll($account)

Return reference to hash with all categorie for account $account.
Hash use id as key, and array as value. Array has two field, first
name of categorie, second id of father categorie

=back

=head1 Private Class Interface

=over

=item getParent($id,%tab)

Rend la chaine correspondante à la catégorie $id avec ses rubriques parentes

=back

=head1 AUTHOR

Alain BARBET alian@alianwebserver.com

=cut
