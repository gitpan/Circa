#!/usr/bin/perl -w
#
# Simple perl exmple to interface with module Circa::Search
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.
#
# $Date: 2001/05/21 22:57:19 $
# $Log: search.pl,v $
# Revision 1.3  2001/05/21 22:57:19  alian
# - Update for use connect and close
#
# Revision 1.2  2001/03/31 19:45:01  alian
# - Ok it's work :-)
#
# Revision 1.1.1.1  2000/09/16 11:26:09  Administrateur

use strict;
use lib '/home/alian/project/Circa/lib';
use Circa::Search;
use Getopt::Long;

my $user = "alian";  # User utilisé
my $pass = ""; # mot de passe
my $db    = "circa";  # nom de la base de données
my $search = new Circa::Search;

if (@ARGV==0)
  {
print "
******************************************************************
            Circa::Search $Circa::Search::VERSION

Usage: search.pl +word='list of word' [+id=id_site]
  [+url=url_restric] [+langue=] [+create=] [+update=]

+word=w   : Search words w
+id=i     : Restrict to site with responsable with id i
+url=u    : Restrict to site with url beginning with u
+langue=l : Restrict to langue l
+create=c : Only url added after this date c (YYYY/MM/DD)
+update=u : Only url updated after this date u (YYYY/MM/DD)
******************************************************************\n";
  exit;
  }

my ($id,$url,$langue,$update,$create,$word);
GetOptions (   "word=s"   => \$word,
	       "id=s"     => \$id,
	       "url=s"     => \$url,
	       "langue=s" => \$langue,
	       "update=s" => \$update,
	       "create=s" => \$create);
if (!$id) {$id=1;}

# Connection à MySQL
if (!$search->connect($user,$pass,$db,"127.0.0.1"))
  {die "Erreur à la connection MySQL:$DBI::errstr\n";}

if (($word) && ($id))
  {
  print "Circa::Search $Circa::Search::VERSION\nRecherche sur $word\n\n";
  my ($resultat,$links,$indice) = 
    $search->search(undef,$word,0,$id,$langue,$url,$create,$update);
  print $resultat;
  }
$search->close;
