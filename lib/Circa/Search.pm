package Circa::Search;

# module Circa::Search : provide function to perform search on Circa
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.

# $Log: Search.pm,v $
# Revision 1.13  2001/06/02 08:17:22  alian
# - Correct a bug in + and - search
#
# Revision 1.12  2001/05/28 23:58:24  alian
# - Add link on name of categorie
#
# Revision 1.11  2001/05/23 00:05:42  alian
# - Correct an another  bug in categories_in_categorie
#
# Revision 1.10  2001/05/22 23:26:45  alian
# - Correct a bug in categories_in_categorie
#
# Revision 1.9  2001/05/21 22:47:40  alian
# - Remove some method use in Search and Indexer and build a father class : Circa.pm
#
# Revision 1.8  2001/05/14 14:55:17  alian
# - Move POD documentation at end of file
# - Update some routine (trouble with CGI)
# - Update getMasque routine. Return undef if no masque
#
# Revision 1.7  2001/04/15 13:35:46  alian
# - Remove use CGI module, use as parameters
#
# Revision 1.6  2001/02/05 00:11:29  alian
# - Add pod documentation
# - Display sites in categories by page (as in search)
# - Add request to stats table
#
# Revision 1.5  2000/11/23 22:53:57  Administrateur
# Add use of template as parameter
#
# Revision 1.4  2000/09/28 15:56:32  Administrateur
# - Update SQL search method
# - Add + and - to syntax of word search
# - Add search in one categorie only
#
# Revision 1.3  2000/09/25 21:39:44  Administrateur
# - Update possibilities to browse several site on a same database
# - Update navigation by category
# - Use new MCD
#

use DBI;
use Circa;
use DBI::DBD;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter Circa);
@EXPORT = qw();
$VERSION = ('$Revision: 1.13 $ ' =~ /(\d+\.\d+)/)[0];

# -------------------
# Template par defaut
my $templateS='"<p>$indiceG - <a href=\"$url\"> $titre </a> $description <br>
    <font class=\"small\"><b>Url:</b> $url <b>Facteur:</b> $facteur
    <b>Last update:</b> $last_update </font></p>\n\n"';
my $templateC='"<p><a href=\"$links\">$nom_complet</a><br></p>\n"';
# -------------------

#------------------------------------------------------------------------------
# new
#------------------------------------------------------------------------------
sub new 
  {
    my $class = shift;
    my $self = $class->SUPER::new;
    bless $self, $class;
    $self->{SCRIPT_NAME} = $ENV{'SCRIPT_NAME'} || 'search.cgi';
    $self->{SIZE_MAX}     = 1000000;  # Size max of file read
    $self->{nbResultPerPage}=10;
    return $self;
  }

#------------------------------------------------------------------------------
# search
#------------------------------------------------------------------------------
sub search
  {
  my ($this,$template,$mots,$first,$idc,$langue,$Url,
      $create,$update,$categorie,$cgi)=@_;
  $this->dbh->do("insert into ".$this->pre_tbl.$idc."stats ".
			"(requete,quand) values('$mots',now())");
  if (!$template) {$template=$templateS;}
  my ($indice,$i,$tab,$nbPage,$links,$resultat,@ind_and,@ind_not,@mots_tmp)
    = (0,0);
  $mots=~s/\'/ /g;
  $mots=~s/(\w)-(\w)/$1 + $2/;
  my @mots = split(/\s/,$mots);
  if (@mots==0) {$mots[0]=$mots;}
  foreach (@mots)
    {
    if    ($_ eq '+') {push(@ind_and,$i);} # Reperage mots 'and'
    elsif ($_ eq '-') {push(@ind_not,$i);} # Reperage mots 'not'
    else {push(@mots_tmp,$_);}
    $i++;
    }
  # Recherche SQL
  $tab=$this->search_word($tab,join("','",@mots_tmp),$idc,
			  $langue,$Url,$create,$update,$categorie);
  # On supprime tout ceux qui ne repondent pas aux criteres and si present
  foreach my $ind (@ind_and) {   print "mp $ind : ",$mots_tmp[$ind],"\n";
    foreach my $url (keys %$tab) {
   
      delete $$tab{$url} if 
	(!$this->appartient($mots_tmp[$ind],@{$$tab{$url}[5]}));}}

  # On supprime tout ceux qui ne repondent pas aux criteres not si present
  foreach my $ind (@ind_not) {
    foreach my $url (keys %$tab) {
      delete $$tab{$url} if 
	($this->appartient($mots_tmp[$ind],@{$$tab{$url}[5]}));}}

  # Tri par facteur
  my @key = reverse sort { $$tab{$a}[2] <=> $$tab{$b}[2] } keys %$tab;

  # Selection des url correspondant à la page demandée
  my $nbResultPerPage;
  if ($cgi) {$nbResultPerPage= $cgi->param('nbResultPerPage') 
	       || $this->{nbResultPerPage};}
  else {$nbResultPerPage= $this->{nbResultPerPage};}
  my $lasto = $first + $nbResultPerPage;
  foreach my $url (@key)
     {
     my ($titre,$description,$facteur,$langue,$last_update)=@{$$tab{$url}};
     my $indiceG=$indice+1;
     if (($indice>=$first)&&($indice<$lasto))
      {
      if ($template) {$resultat.= eval $template;}
      else {$resultat.=$url."\t".$titre."\n";}
      }
     # Constitution des liens suivants / precedents
    if (!($indice%$nbResultPerPage))
      {
      $nbPage++;
      if ($indice==$first) {$links.="$nbPage- ";}
      elsif ($ENV{"SCRIPT_NAME"}) 
	{$links.='<a class="liens_suivant" href="'.
	   $this->get_link($indice,$cgi).'">'.$nbPage.'</a>- '."\n";}
      }
    $indice++;
    }
  if (@key==0) {$resultat="<p>Aucun document trouvé.</p>";}
  return ($resultat,$links,$indice);
  }

#------------------------------------------------------------------------------
# search_word
#------------------------------------------------------------------------------
sub search_word
  {
  my ($self,$tab,$word,$idc,$langue,$Url,$create,$update,$categorie)=@_;
  # Restriction diverses
  # Lang
  if ($langue) {$langue=" and langue='$langue' ";} else {$langue= ' ';}
  # url
  if (($Url)&&($Url ne 'http://')) {$Url=" and url like '$Url%' ";}    
  else {$Url=' ';}
  # date created
  if ($create) 
    {$create="and unix_timestamp('$create')< unix_timestamp(last_check) ";}  
  else {$create=' ';}
  # date last update
  if ($update) 
    {$update="and unix_timestamp('$update')< unix_timestamp(last_update) ";} 
  else {$update=' ';}
  # Categorie
  if ($categorie)
    {
    my @l=$self->get_liste_categorie_fils($categorie,$idc);
    if (@l) {$categorie="and l.categorie in (".join(',',@l).')';}
    else {$categorie="and l.categorie=$categorie";}
    }
  else {$categorie=' ';}

  my $requete = "
    select   facteur,url,titre,description,langue,last_update,mot
    from   ".$self->pre_tbl.$idc."links l,".
             $self->pre_tbl.$idc."relation r
    where   r.id_site=l.id
    and   l.valide=1
    and   r.mot in ('$word')
    $langue $Url $create $update $categorie
    order   by facteur desc";

  my $sth = $self->dbh->prepare($requete);
  #print "requete:$requete\n";
  $sth->execute() || print "Erreur $requete:$DBI::errstr\n";
  while (my ($facteur,$url,$titre,$description,$langue,$last_update,$mot)
	 =$sth->fetchrow_array)
    {
    $$tab{$url}[0]=$titre;
    $$tab{$url}[1]=$description;
    $$tab{$url}[2]+=$facteur;
    $$tab{$url}[3]=$langue;
    $$tab{$url}[4]=$last_update;
    push(@{$$tab{$url}[5]},$mot);
    }
  return $tab;
  }


#------------------------------------------------------------------------------
# categories_in_categorie
#------------------------------------------------------------------------------
sub categories_in_categorie
  {
  my ($self,$id,$idr,$template)=@_;
  $idr=1 if !$idr;
  $id=0  if !$id;
  $template=$templateC if !$template;
  my (@buf,%tab,$titre);
  # On charge toutes les categories
  my $ref = $self->categorie->loadAll($idr);
  if (ref($ref)) { %tab = %$ref;}
  else { die "$ref\n";}
  foreach my $key (keys %tab)
    {
    my $nom_complet;
    my ($nom,$parent)=($tab{$key}[0],$tab{$key}[1]);
    $nom_complet=$self->categorie->getParent($key,%tab);
    my $links = $self->get_link_categorie($key,$idr);
    if ($parent==$id) {push(@buf,eval $template);}
    }
  if ($#buf==-1) {$buf[0]="<p>Plus de catégorie</p>";}
  if ($id!=0) 
    {
       my $lin = $self->get_link_categorie($tab{$id}[1],$idr);
       my $nom_complet=$self->categorie->getParent($tab{$id}[1],%tab);
       $titre = "<a class=\"categorie\" href=\"".$ENV{'SCRIPT_NAME'}.
             "?browse_categorie=1&id=$idr\">Accueil</a> 
                <a class=\"categorie\" href=\"".$lin."\">$nom_complet</a>";
      
   }
  return ($titre,@buf);
  }

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub sites_in_categorie
  {
  my $self=shift;
  my ($id,$idr,$template,$first)=@_;
  if (!$idr) {$idr=1;}
  if (!$id) {$id=0;}
  if (!$template) {$template=$templateS;}
  my ($buf,$buf_l);
  my $requete = "
  select   url,titre,description,langue,last_update
  from   ".$self->{PREFIX_TABLE}.$idr."links
  where   categorie=$id and browse_categorie='1' and parse='1'";
  my $sth = $self->{DBH}->prepare($requete);
  $sth->execute() || print "Erreur $requete:$DBI::errstr\n";
  my ($facteur,$indiceG)=(100,0);
  while (my ($url,$titre,$description,$langue,$last_update)
	 = $sth->fetchrow_array)
    {
    if ($last_update eq '0000-00-00 00:00:00') {$last_update='?';}
    if (defined($first))
      {
      if ($indiceG>=$first and ($indiceG<($first+$self->{nbResultPerPage}))) {$buf.= eval $template;}
      if (!($indiceG%$self->{nbResultPerPage}))
        {
        if ($indiceG==$first) {$buf_l.=(($indiceG/$self->{nbResultPerPage})+1).' -';}
          else {$buf_l .= '<a class="liens_suivant" href="'.$self->get_link_categorie($id,$idr,$indiceG).'">'.(($indiceG/$self->{nbResultPerPage})+1).'</a>-';}
        }
      }
    else {$buf.= eval $template;}
    $indiceG++;
    }
  if ($indiceG>$self->{nbResultPerPage} and defined($first)) {chop($buf_l);$buf_l='<p class="liens_suivant">&lt;'.$buf_l.'&gt;</p>';}
  if (!$buf) {$buf="<p>Pas de pages dans cette catégorie</p>";}
  if (wantarray()) {return ($buf,$buf_l);}
  else {return $buf;}
  }


#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub get_link
  {
  my ($self,$first,$cgi) = @_;  
  my $buf = $self->{SCRIPT_NAME}."?word=".$cgi->escape($cgi->param('word')).
       "&id=".$cgi->param('id')."&first=".$first;
  if ($cgi->param('nbResultPerPage')) 
    {$buf.="&nbResultPerPage=".$cgi->param('nbResultPerPage');}
  return $buf;
  }


#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub get_link_categorie
  {
  my ($self,$no_categorie,$id,$first) = @_;
  if (defined($first)) {return $self->{SCRIPT_NAME}."?categorie=$no_categorie&id=$id&first=$first";}
  else {return $self->{SCRIPT_NAME}."?categorie=$no_categorie&id=$id";}
  }

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub advanced_form
  {
  my $self=shift;
  my ($id)=$_[0] || 1;
  my $cgi = $_[1];
  my @l;
  my $sth = $self->{DBH}->prepare("select distinct langue from ".$self->{PREFIX_TABLE}.$id."links");
  $sth->execute() || print "Erreur: $DBI::errstr\n";
  while (my ($l)=$sth->fetchrow_array) {push(@l,$l);}
  $sth->finish;
  my %langue=(
	      'da'=>'Dansk',
	      'de'=>'Deutsch',
	      'en'=>'English',
	      'eo'=>'Esperanto',
	      'es'=>'Espanõl',
	      'fi'=>'Suomi',
	      'fr'=>'Francais',
	      'hr'=>'Hrvatski',
	      'hu'=>'Magyar',
	      'it'=>'Italiano',
	      'nl'=>'Nederlands',
	      'no'=>'Norsk',
	      'pl'=>'Polski',
	      'pt'=>'Portuguese',
	      'ro'=>'Românã',
	      'sv'=>'Svenska',
	      'tr'=>'TurkCe',
	      '0'=>'All'
    );
  my $scrollLangue =
    "Langue :".
    $cgi->scrolling_list(  -'name'=>'langue',
                           -'values'=>\@l,
                           -'size'=>1,
                           -'default'=>'All',
                           -'labels'=>\%langue);
  my @lno = (5,10,20,50);
  my $scrollNbPage = "Nombre de resultats par page:".
    $cgi->scrolling_list(  -'name'=>'nbResultPerPage',
                           -'values'=>\@lno,
                           -'size'=>1,
                           -'default'=>'5');
  my $buf=$cgi->start_form.
    '<table align=center>'.
    Tr(td({'colspan'=>2}, [h1("Recherche")])).
    Tr(td(  textfield(-name=>'word')."<br>\n".
      hidden(-name=>'id',-value=>1)."\n".
      $scrollNbPage."<br>\n".
      $scrollLangue."<br>\n".
      "Sur le site: ".textfield({-name=>'url',-size=>12,-default=>'http://'})."<br>\n".
      "Modifié depuis le: ".textfield({-name=>'update',-size=>10,-default=>''})."(YYYY:MM:DD)<br>\n".
      "Ajouté depuis le: ".textfield({-name=>'create',-size=>10,-default=>''})."(YYYY:MM:DD)<br>\n"
         ),
       td($cgi->submit))."\n".
    '</table>'.
    $cgi->end_form."<hr>";
  my ($cate,$titre)=$self->categories_in_categorie(undef,$id);
  $buf.=  h1("Navigation par catégorie (repertoire)").
    h2("Catégories").$cate.
    h2("Pages").$self->sites_in_categorie(undef,$id);
  return $buf;
  }


#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub default_form
  {
  my ($self,$cgi)=@_;
  my $buf=$cgi->start_form.
    '<table align=center>'.
    Tr(td({'colspan'=>2}, [h1("Recherche")])).
    Tr(td(  textfield(-name=>'word')."<br>\n".
	    hidden(-name=>'id',-value=>1)."\n"),
       td($cgi->submit))."\n".
    '</table>'.
    $cgi->end_form;
  return $buf;
  }

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub get_liste_langue
  {
  my ($self,$cgi)=@_;
  my %langue=(
      'da'=>'Dansk',
    'de'=>'Deutsch',
    'en'=>'English',
    'eo'=>'Esperanto',
      'es'=>'Espanõl',
      'fi'=>'Suomi',
    'fr'=>'Francais',
      'hr'=>'Hrvatski',
      'hu'=>'Magyar',
    'it'=>'Italiano',
        'nl'=>'Nederlands',
      'no'=>'Norsk',
      'pl'=>'Polski',
        'pt'=>'Portuguese',
      'ro'=>'Românã',
        'sv'=>'Svenska',
      'tr'=>'TurkCe',
    '0'=>'All'
    );
  my @l =keys %langue;
  return $cgi->scrolling_list(  -'name'=>'langue',
                           -'values'=>\@l,
                           -'size'=>1,
                           -'default'=>$cgi->param('langue'),
                           -'labels'=>\%langue);
        }


#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub get_name_site
  {
  my($this,$id)=@_;
  my $sth = $this->{DBH}->prepare("select titre from ".$this->{PREFIX_TABLE}."responsable where id=$id");
  $sth->execute() || print "Erreur: $DBI::errstr\n";
  my ($titre)=$sth->fetchrow_array;
  $sth->finish;
  return $titre;
  }


#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub get_liste_categorie_fils
  {
  my ($self,$id,$idr)=@_;
  sub get_liste_categorie_fils_inner
    {
    my ($id,%tab)=@_;
    my (@l,@l2);
    foreach my $key (keys %tab) {push (@l,$key) if ($tab{$key}[1]==$id);}
    foreach (@l) {push(@l2,get_liste_categorie_fils_inner($_,%tab));}
    return (@l,@l2);
    }
  my $tab = $self->categorie->loadAll;
  return get_liste_categorie_fils_inner($id,%$tab);
  }


#------------------------------------------------------------------------------
# POD DOCUMENTATION
#------------------------------------------------------------------------------

=head1 NAME

Circa::Search - provide functions to perform search on Circa, a www search
engine running with Mysql

=head1 SYNOPSIS

 use Circa::Search;
 my $search = new Circa::Search;

 # Connection à MySQL
 if (!$search->connect("aliansql","pass","my_database","localhost"))
  {die "Erreur à la connection MySQL:$DBI::errstr\n";}

 # Affichage d'un formulaire minimum
 print   header,
   $search->start_classic_html,
   $search->default_form;

 # Interrogation du moteur
 # Sites trouves, liens pages suivantes, nb pages trouvees
 my ($resultat,$links,$indice) = $search->search('informatique internet',0,1);


=head1 DESCRIPTION

This is Circa::Search, a module who provide functions to
perform search on Circa, a www search engine running with
Mysql. Circa is for your Web site, or for a list of sites.
It indexes like Altavista does. It can read, add and
parse all url's found in a page. It add url and word
to MySQL for use it at search.

Notes:

=over

=item *

Accents are removed on search and when indexed

=item *

Search are case unsensitive (mmmh what my english ? ;-)

=back

Circa::Search work with Circa::Indexer result. Circa::Search is a Perl 
interface, but it's exist on this package a PHP client too.

=head1 VERSION

$Revision: 1.13 $

=head1 Class Interface

=head2 Constructors and Instance Methods

=over

=item new

Create new instance of Circa::Search

=back

=head2 Search method

=over

=item search($tab,$mot,$idc,$langue,$url,$create,$update,$categorie)

Main method of this module.  This function anlayse request of user,
build and make the SQL request on Circa, and return HTML result.
Circa support "not", "and", and "or"  by default.

=over

=item *

To make request with "not" : circa - alian (not idem :circa-alian who search circa and alian)

=item *

To make request with "and" : circa + alian

=item *

To make request with "or" : circa alian (default).

=back

Parameters:

=over 4

=item $template

HTML template used for each link found. If undef, default template will be used
(defined at top of this file). Variables names used are : $indiceG,$titre,$description,
$url,$facteur,$last_update,$langue

Example :

  '"<p>$indiceG - <a href=\"$url\">$titre</a> $description<br>
   <font class=\"small\"><b>Url:</b> $url <b>Facteur:</b> $facteur
   <b>Last update:</b> $last_update </font></p>\n"'

=item $mot

Search word sequence hit by user

Séquence des mots recherchés tel que tapé par l'utilisateur

=item first

Number of first site print.

Indice du premier site affiché dans le résultat

=item $id

Id of account

Id du site dans lequel effectué la recherche

=item $langue

Restrict by langue

Restriction par langue (facultatif)

=item $Url

Restriction par url : les url trouvées commenceront par $Url (facultatif)

=item $create

Restriction par date inscription. Format YYYY-MM-JJ HH:MM:SS (facultatif)

=item $update

Restriction par date de mise à jour des pages. Format YYYY-MM-JJ HH:MM:SS (facultatif)

=item $catego

Restriction par categorie (facultatif)

=back

Retourne ($resultat,$links,$indice)

=over

=item $resultat

Buffer HTML contenant la liste des sites trouves formaté en fonction de $template et des
mots present dans $mots

=item $links

Liens vers les pages suivantes / precedentes

=item $indice

Nombre de sites trouves

=back

=item search_word($tab,$word,$idc,$langue,$Url,$create,$update,$categorie)

Make request on Circa. Call by search

=over

=item *

$tab    : Reference du hash où mettre le resultat

=item *

$word   : Mot recherché

=item *

$id     : Id du site dans lequel effectué la recherche

=item *

$langue : Restriction par langue (facultatif)

=item *

$Url    : Restriction par url

=item *

$create : Restriction par date inscription

=item *

$update : Restriction par date de mise à jour des pages

=item *

$catego : Restriction par categorie

=back

Retourne la reference du hash avec le resultat de la recherche sur le mot $word
Le hash est constitué comme tel:

      $tab{$url}[0] : titre
      $tab{$url}[1] : description
      $tab{$url}[2] : facteur
      $tab{$url}[3] : langue
      $tab{$url}[4] : date de dernière modification
   @{$$tab{$url}[5]}: liste des mots trouves pour cet url

=item categories_in_categorie($id,$idr,[$template])

Fonction retournant la liste des categories de la categorie $id dans le site $idr

=over

=item *

$id  Id de la categorie de depart. Si undef, 0 est utilisé (Considéré 
comme le "Home")


=item *

$idr Id du responsable

=item *

$template : Masque HTML pour le resultat de chaque lien. Si undef, le 
masque par defaut (defini en haut de ce module) sera utlise

=back

Retourne ($resultat,$nom_categorie) :

=over

=item *

$resultat : Buffer contenant la liste des sites formatées en ft de $template

=item *

$nom_categorie : Nom court de la categorie

=back

=item sites_in_categorie($id, $idr, [$template], [$first])

Fonction retournant la liste des pages de la categorie $id dans le site $idr

=over

=item *

$id       : Id de la categorie de depart. Si undef, 0 est utilisé (Considéré comme le "Home")

=item *

$idr     : Id du responsable

=item *

$template : Masque HTML pour le resultat de chaque lien. Si undef, le 
masque par defaut (defini en haut de ce module) sera utlise

=item *

$first : If present return only site from $first to 
$first + $self->{nbResultPerPage} and a buffer with link to other pages

=back

Retourne le buffer contenant la liste des sites formatées en ft de $template

=back

=head2 HTML methods

=over

=item get_link($no_page,$id)

Retourne l'URL correspondant à la page no $no_page dans la recherche en cours

=item get_link_categorie($no_categorie,$id,$first)

Retourne l'URL correspondant à la categorie no $no_categorie

=item advanced_form([$id],$cgi)

Affiche un formulaire minimum pour effectuer une recherche sur Circa

=item default_form

Affiche un formulaire minimum pour effectuer une recherche sur Circa

=item get_liste_langue($cgi)

Retourne le buffer HTML correspondant à la liste des langues disponibles

=item get_name_site($id)

Retourne le nom du site dans la table responsable correspondant à l'id $id

=item get_liste_categorie_fils($id,$idr)

 $id : Id de la categorie parent
 $idr : Site selectionne

Retourne la liste des categories fils de $id dans le site $idr

=back

=head1 AUTHOR

Alain BARBET alian@alianwebserver.com

=cut

1;
