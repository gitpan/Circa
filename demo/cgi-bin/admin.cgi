#!/usr/bin/perl -w
#
# Simple CGI interface to module Circa::Indexer
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.
# Take a look in admin.htm
#

use lib "/home/alian/circa";
use strict;
use CGI qw/:standard :html3 :netscape escape unescape/;
use CGI::Carp qw/fatalsToBrowser/;
use Circa::Indexer;

$|=1;
my $user = "alian";  # User utilisé
my $pass = "";   # mot de passe
my $db    = "circa";  # nom de la base de données
# Repertoire des ecrans
my $rep = "/home/alian/circa/demo/ecrans/";   

# $Date: 2001/06/02 08:32:04 $
# $Log: admin.cgi,v $
# Revision 1.9  2001/06/02 08:32:04  alian
# - Modif de la directive use lib
#
# Revision 1.8  2001/05/21 23:01:01  alian
# - Update for use connect and close
#
# Revision 1.7  2001/03/31 19:11:54  alian
# - Add export and import features
#
# Revision 1.6  2001/03/29 22:42:14  alian
# - Update parameters for INSTALL file
#
# Revision 1.5  2000/11/23 22:16:34  Administrateur
# Add template as parameter
#
# Revision 1.1.1.1  2000/09/09 17:08:58  Administrateur
# Release initiale
#

my $masque = $rep."admin.htm";
my $masqueClients = "/tmp/";
my $indexor = new Circa::Indexer;
#$indexor->proxy("http://192.168.100.70:3128");
$|=1;

my $cgi = new CGI;
print header,$indexor->start_classic_html($cgi);
#if (defined $ENV{'MOD_PERL'}) {print "Mode mod_perl<br>\n";}
#else {print "Mode cgi<br>\n";}
if (!$indexor->connect($user,$pass,$db,"localhost")) 
  {die "Erreur à la connection MySQL:$DBI::errstr\n";}

# Drop table
if (param('drop')) 
  {$indexor->drop_table_circa; print h1("Tables supprimées"); }

# Drop compte
if (param('dropSite')) 
  { $indexor->drop_table_circa_id(param('id')); print h1("Comte supprimé"); }

# Create table
if (param('create')) 
  {$indexor->create_table_circa; print h1("Tables créées"); }

# Add site
if (param('url'))
  {
  $indexor->addSite(param('url'),param('email'),param('titre'),
		    param('categorieAuto'),$cgi,$masqueClients);
  print h1("Site ajouté");
  }
# export data
if (param('export')) {$indexor->export(undef,$masqueClients);}
# import data
if (param('import')) {$indexor->import_data(undef,$masqueClients);}
# Add local site
if (param('local_url'))
  {
  $indexor->addLocalSite(
    param('local_url'),
    param('email'),
    param('titre'),
    param('local_file'),
    param('url_racine'),
    param('local_file_site'),
    param('categorieAuto'),
    $cgi,
    $masqueClients);
  print h1("Site ajouté");
  }

# Read url not parsed
if (param('parse_new'))
  {
  my ($nbIndexe,$nbAjoute,$nbWords,$nbWordsGood) 
    = $indexor->parse_new_url(param('id'));
  print "$nbIndexe pages indexées, $nbAjoute pages ajoutées, ",
  "$nbWordsGood mots indexés, $nbWords mots lus\n";
  }

# Update index
if (param('update')) 
  {$indexor->update(param('nb_jours'),param('id'));}

my @l = (0,1);
my %tab=(0=>'Non',1=>'Oui');
my $list = $cgi->scrolling_list(-'name'=>'categorieAuto',
                           -'values'=>\@l,
                           -'size'=>1,
                           -'labels'=>\%tab);
# Liste des variables à substituer dans le template
my %vars = ('liste_site'=> $indexor->get_liste_site($cgi),'categories'=>$list);
# Affichage du resultat
print $indexor->fill_template($masque,\%vars),end_html;

# Close connection
$indexor->close;
