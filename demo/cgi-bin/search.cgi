#!/usr/bin/perl -w
#
# Simple CGI interface to module Circa::Search
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.
#
# $Date: 2001/06/02 08:33:32 $
# $Log: search.cgi,v $
# Revision 1.9  2001/06/02 08:33:32  alian
# - Update directive use lib
# - Add control when template is return (masque)
#
# Revision 1.8  2001/05/21 23:01:01  alian
# - Update for use connect and close
#
# Revision 1.7  2001/05/15 08:33:13  alian
# - Use a default template if not defined in db
#
# Revision 1.6  2001/04/15 13:37:19  alian
# - Use CGI module as parameter with Search.pm


use strict;
use CGI qw/:standard :html3 :netscape escape unescape/;
use CGI::Carp qw/fatalsToBrowser/;
use lib "/home/alian/circa";
use Circa::Search;

my $user = "alian";   # User utilisé
my $pass = "";        # mot de passe
my $db    = "circa";  # nom de la base de données
my $rep = "/home/alian/circa/demo/ecrans/";

# Default file template for result
my $masque = $rep."circa.htm";

# Default display of item link
my $templateS='"<li>&nbsp;&nbsp;".($indiceG+1)." - <a href=\"$url\">$titre</a> $description<br>
    <font class=\"small\"><b>Url:</b> $url <b>Last update:</b> $last_update </font></li>\n"';

# default display of category link
my $templateC='"<p>$nom_complet<br></p>\n"';


my $search = new Circa::Search;
my $cgi = new CGI;
print header;

# Connection à MySQL
if (!$search->connect($user,$pass,$db,"localhost"))
  {die "Erreur à la connection MySQL:$DBI::errstr\n";}
my $id = param('id') || 1;
# Navigation par mot-clef
if ( param('word') )
  {
  # Interrogation du moteur et tri du resultat par facteur
  my $mots=param('word');
  my $first = param('first') ||0;
  my ($masque) = $search->categorie->get_masque($id) || $masque;
  my ($resultat,$links,$indice) = $search->search(
    undef,$mots,$first,
    param('id')||1,
    param('langue')||undef,
    param('url')||undef,
    param('create')||undef,
    param('update')||undef,
    param('categorie')||undef,
    $cgi
    );
  if ($indice==0) {$resultat="<p>Aucun document trouvé.</p>";}
  if ($indice!=0) {$indice="$indice page(s) trouvée(s)";} else {$indice=' ';}
  # Liste des variables à substituer dans le template
  my %vars = ('resultat'     => $resultat,
            'titre'    => "Recherche sur ".$search->get_name_site($id),
            'listeLiensSuivPrec'=> $links,
            'words'    => param('word'),
            'id'    => param('id'),
            'categorie'    => param('categorie')||0,
            'listeLangue'  => $search->get_liste_langue($cgi),
            'nb'    => $indice);
  # Affichage du resultat
  print $search->fill_template($masque,\%vars),end_html;
  }
# Navigation par catégorie
else
  {
  my ($categorie,$id);
  if (!param('categorie')) {$categorie=0;}
  else {$categorie=param('categorie');}
  if (!param('id')) {$id=1;}
  else {$id=param('id');}
  my ($masque) = $search->categorie->get_masque($id,$categorie) || $masque;
  my ($titre,@cates) = $search->categories_in_categorie($categorie,$id);
  my ($sites,$liens) = $search->sites_in_categorie($categorie,$id,$templateS,param('first'));
  # Substitution dans le template
  my %vars = ('resultat'     => $sites,
        'categories1'  => join(' ',@cates[0..$#cates/2]),
        'categories2'  => join(' ',@cates[($#cates/2)+1..$#cates]),
            'titre'    => h3('Annuaire').'<p class="categorie">'.($titre).'</p>',
            'listeLiensSuivPrec'=> $liens,
            'words'    => ' ',
            'categorie'    => $categorie,
            'id'    => $id,
            'listeLangue'  => $search->get_liste_langue($cgi),
            'nb'    => 0);
  # Affichage du resultat
  print $search->fill_template($masque,\%vars),end_html;
  }
$search->close;
