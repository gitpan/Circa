package Circa::Parser;

# module Circa::Parser : See Circa::Indexer
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.

# $Log: Parser.pm,v $
# Revision 1.8  2001/05/28 22:32:02  alian
# - Move load to HTML::Parser to new method. If not found, use a basic parser. (without link)
#
# Revision 1.7  2001/05/28 18:40:03  alian
# - Add trace for debug mode
#
# Revision 1.6  2001/05/28 15:35:19  alian
# - Move LWP::UserAgent call that use HTML::Parser in eval statement
#
# Revision 1.5  2001/05/22 23:25:39  alian
# - Add a BEGIN / eval statement for use HTML::Parser 3.0.
# It warn if it can't be find, but Circa without parsing can be run
# - Correct a fonction call for local url.
#
# Revision 1.4  2001/05/21 23:02:08  alian
# - Update for use new Circa facilities
#
# Revision 1.3  2001/05/20 11:28:25  alian
# - Add some word to %bad
# - Use new add & update of class url method
#
# Revision 1.2  2001/05/14 22:21:57  alian
# - Update POD documentation
# - Correct call to categorie method
#
# Revision 1.1  2001/05/14 17:49:06  alian
# - Code extrait de Indexer.pm
#
#

use strict;
use URI::URL;
use DBI;
use LWP::RobotUA; 
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION 
	    %links %inside $TEXT $DESCRIPTION $KEYWORDS);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw();
$VERSION = ('$Revision: 1.8 $ ' =~ /(\d+\.\d+)/)[0];

# Mot à ne pas indexer
my %bad = map {$_ => 1} qw (
  le la les et des de and or the un une ou qui que quoi a an
  &quot je tu il elle nous vous ils elles eux ce cette ces cet celui celle ceux
  celles qui que quoi dont ou mais ou et donc or ni car parceque un une des
  pour votre notre avec sur par sont pas mon ma mes tes ses the from for and 
  our my his her and your to in that else also with this you date not has net 
  but can see who dans est \$ { & com/ + son tous plus com www html htm are
  file/); 

#------------------------------------------------------------------------------
# new
#------------------------------------------------------------------------------
sub new 
  {
    my $class = shift;
    my $self = {};
    my $indexer = shift;
    bless $self, $class;
    $self->{DBH} = $indexer->{DBH};
    $self->{ConfigMoteur} = $indexer->{ConfigMoteur};
    $self->{INDEXER} = $indexer;
    # Ce module n'est presque jamais installé !
    # Evidemment cela demande une charge machine et un .so 
    # compilé pour cet environnement. Ca fait peur aux admin
    # ISP ! On encapsule donc l'appel, si on echoue, on previent que
    # tout appel au parser se soldera par une utilisation d'un parseur basic
    # sans handicaper le reste de l'application
    # Il vous reste plus qu'a faire alors une install mysql/circa en local
    # pour faire l'indexation, et exporter les resultats sur le serveur final.
    $self->{_parser_ok}=1;
    eval { require HTML::Parser };
    if ($@ || $HTML::Parser::VERSION < 3.0)
      {
	warn "Module HTML-Parser 3.0 ou superieur requis pour ".
	  "utiliser les fonctionnalités optimales du parser.($@)\n";
	$self->{_parser_ok}=0;
      }
    else { use HTML::Entities; }    
    print "Parser::new\n" if ($self->{INDEXER}->{DEBUG});
    return $self;
  }

#------------------------------------------------------------------------------
# tag
#------------------------------------------------------------------------------
sub tag
  {
    my($tag, $num, $att) = @_; # parametre
    # On est dans le cas d'un meta    
    if ((defined(%$att)) and ($tag eq 'meta'))
      {
	my $name = $$att{name} || undef;
	if ($name and (lc($name) eq 'description')) # Description
	  {$DESCRIPTION =$$att{content};}
	elsif ((lc($$att{'http-equiv'}) eq 'keywords') || 
	       (lc($name) eq 'keywords'))# Mots-clefs
	  {$KEYWORDS=$$att{content} ;}
      }
    # Liens exterieurs
    if (($tag eq 'a') and ($$att{href})) {$links{$$att{href}}=1;}
    # Frame
    if (($tag eq 'frame') and ($$att{src})) {$links{$$att{src}}=1;}
    $inside{$tag} += $num;   # Profondeur de la balise
  }

#------------------------------------------------------------------------------
# text
#------------------------------------------------------------------------------
sub text
  {
    my ($tex)=@_;
    return if $inside{script} || $inside{style};
    # On ne doit pas modifier la presentation dans une balise pre ...
    if (!$inside{pre}) {$tex=~s/\\n//g;}
    # Buffer final epuré
    $TEXT.=$tex;
  }                      

#------------------------------------------------------------------------------
# look_at
#------------------------------------------------------------------------------
sub look_at
  {
  my($this,$url,$idc,$idr,$lastModif,$url_local,$categorieAuto,$niveau,$categorie) = @_;
  print "Parser::look_at\n" if ($this->{INDEXER}->{DEBUG});
  my ($l,$url_orig,$racineFile,$racineUrl,$lastUpdate);
  if ($url_local) {$this->set_agent(1);}
  else {$this->set_agent(0);}
  if ($url_local)
    {
      $this->{ConfigMoteur}->{'temporate'}=0;
      if ($url_local=~/.*\/$/)
	{
	  chop($url_local);
	  if (-e "$url_local/index.html") {$url_local.="/index.html";}
	  elsif (-e "$url_local/index.htm") {$url_local.="/index.htm";}
	  elsif (-e "$url_local/default.htm") {$url_local.="/default.htm";}
	  else {return (-1,0,0);}
	}
      $url_orig=$url;
      $url=$url_local;
      ($racineFile,$racineUrl) = 
	$this->{INDEXER}->fetch_first("select path,url from ".
			 $this->{INDEXER}->pre_tbl."local_url where id=$idr");
    }
  print "Analyse de $url<br>\n";
  
  my ($nb,$nbwg,$nburl)=(0,0,0);
  if ($url_local) {$this->{INDEXER}->set_host_indexed($url_local);}
  else {$this->{INDEXER}->set_host_indexed($url);}

  # Creation d'une requete
  # On passe la requete à l'agent et on attend le résultat
  my $res = $this->{AGENT}->request(new HTTP::Request('GET' => $url));

  if ($res->is_success)
    {
      # Langue
      my $language = $res->content_language || 'unkno';
      # Fichier non modifie depuis la derniere indexation
      if (($lastModif) && ($res->last_modified) &&
	  ($lastModif > $res->last_modified))
	{
	  print "No update on $url<br>\n" if ($this->{DEBUG});
	  $this->{INDEXER}->URL->update
	    ($idr,('id'=>$idc, 
		   'last_check'=>"CURRENT_TIMESTAMP"));
	  return (0,0,0);
	}
      if ($res->last_modified)
	{
	  my @date = localtime($res->last_modified);
	  $lastUpdate = ($date[5]+1900).'-'.($date[4]+1).'-'.
	    $date[3].' '.$date[2].':'.$date[1].':'.$date[0];
	}
      else {$lastUpdate='0000-00-00';}
      # Il serait judicieux de mettre ca dans le constructeur,
      # mais cela entraine 10 Mo de Ram supplementaire à 
      # l'utilisation. A voir avec les evolution du module
      # HTML::Parser
      if ($this->{_parser_ok})
	{
	  print "Use HTML::Parser ...\n" if ($this->{INDEXER}->{DEBUG});
	  my $parser = HTML::Parser->new
	    (api_version => 3,
	     handlers => [start => [\&tag, "tagname, '+1', attr"],
			  end   => [\&tag, "tagname, '-1', attr"],
			  text  => [\&text, "dtext"],
			 ],
	     marked_sections => 1);
	  # parse du fichier
	  $parser->parse($res->content)
	    || print STDERR "Can't parse ".$res->content."::$!\n"; 
	}
      else
	{
	  print "Use a basic parser ...\n" if ($this->{INDEXER}->{DEBUG});
	  $TEXT = $res->content;
	  $TEXT=~s{ <! (.*?) (--.*?--\s*)+(.*?)> } 
	          {if ($1 || $3) {"<!$1 $3>";} }gesx;
	  $TEXT=~s{ <(?: [^>\'\"] * | ".*?" | '.*?' ) + > }{}gsx;
	  $TEXT=decode_entities($TEXT);
	}

      # Mots clefs et description
      my ($desc,$keyword)=($DESCRIPTION||' ',$KEYWORDS||' ');
      undef $DESCRIPTION; undef $KEYWORDS; 
      my $titre = $res->title || $url;# Titre
      foreach ($titre,$desc,$keyword){ s/0x39/\\0x39/g if ($_); }	  
      # Categorie
      if ($categorieAuto) 
	{$categorie = $this->{INDEXER}->categorie->get($url,$idr);}
      if (!$categorie) {$categorie=0;}
      # Mis a jour de l'url
      $this->{INDEXER}->URL->update
	($idr,
	 (parse        => 1,
	  id           => $idc,
	  titre        => $titre,
	  description  => $desc,
	  last_update  => $lastUpdate,
	  last_check   => 'NOW()',
	  langue       => $language,
	  categorie    => $categorie
	 )
	);
	  
      # Traitement des mots trouves
      $l=analyse($keyword,$this->{ConfigMoteur}->{'facteur_keyword'},%$l);
      $l=analyse($desc,$this->{ConfigMoteur}->{'facteur_description'},%$l);
      $l=analyse($titre,$this->{ConfigMoteur}->{'facteur_titre'},%$l);
      $l=analyse($TEXT,$this->{ConfigMoteur}->{'facteur_full_text'},%$l);
      $l=analyse($url,$this->{ConfigMoteur}->{'facteur_url'},%$l);
      $this->{INDEXER}->dbh->do
	("delete from ".$this->{INDEXER}->pre_tbl.$idr."relation ".
		       "where id_site = $idc");
      undef $TEXT;
      # Chaque mot trouve plus de $ConfigMoteur{'nb_min_mots'} fois
      # est enregistre
      while (my ($mot,$nb)=each(%$l))
        {
	  my $requete = "insert into ".
                       $this->{INDEXER}->pre_tbl.$idr.
                       "relation (mot,id_site,facteur) ".
                       "values ('$mot',$idc,$nb)";
        if ($nb >=$this->{'ConfigMoteur'}{'nb_min_mots'}) 
          {$this->{DBH}->do($requete);$nbwg++;}
        }
      my $nbw=keys %$l;undef(%$l);
      # On n'indexe pas les liens si on est au niveau max
      if ($niveau == $this->{ConfigMoteur}->{'niveau_max'})
        {
        print "Niveau max atteint. Liens suivants de cette page ignorés<br>\n" 
	  if ($this->{DEBUG});
        return (0,0,0);
        }  
      # Traitement des url trouves
      my $base = $res->base;
      my @l = keys %links; undef %links;
      foreach my $var (@l)
        {
	  $var = url($var,$base)->abs; # Url absolu
	  $var = $this->check_links('a',$var);
	  if (($url_local) && ($var))
	    {
	      my $urlb = $var;
	      $urlb=~s/$racineFile/$racineUrl/g;
	      #print h1("Ajout site local:$$var[2] pour $racineFile");
	      $this->{INDEXER}->URL->add($idr,
					 (url       => $urlb, 
					  local_url => $var,
					  niveau    => $niveau+1,
					  categorie => $categorie,
					  valide    => 1)) && $nburl++;
	    }
	  elsif ($var) 
	    {
	      $this->{INDEXER}->URL->add($idr,(url       => $var,
					       niveau    => $niveau+1,
					       categorie => $categorie,
					       valide => 1))
		&& $nburl++;
	    }
        }
      return ($nburl,$nbw,$nbwg);
    }
  # Sinon previent que URL defectueuse
  else {print "Url non valide:$url\n";return (-1,0,0);}
}

#------------------------------------------------------------------------------
# set_agent
#------------------------------------------------------------------------------
sub set_agent
  {
  my ($self,$locale)=@_;
  return if ($self->{AGENT} && $self->{_ROBOT}==$locale); # agent already set
  $self->{_ROBOT}=$locale;
  
  if (($self->{ConfigMoteur}->{'temporate'}) && (!$locale))
    {
      $self->{AGENT} = new LWP::RobotUA('CircaIndexer / $Revision: 1.8 $', 
                                       $self->{ConfigMoteur}->{'author'});
      $self->{AGENT}->delay(10/60.0);
    }
  else {$self->{AGENT} = new LWP::UserAgent 'CircaIndexer / $Revision: 1.8 $', $self->{ConfigMoteur}->{'author'};}
  if ($self->{PROXY}) {$self->{AGENT}->proxy(['http', 'ftp'], $self->{PROXY});}
  $self->{AGENT}->max_size($self->{INDEXER}->size_max) 
    if ($self->{INDEXER}->size_max);
  $self->{AGENT}->timeout(25); # Set timeout to 25s (defaut 180)
  }

#------------------------------------------------------------------------------
# analyse
#------------------------------------------------------------------------------
sub analyse
  {
  my ($data,$facteur,%l) = @_;
  if ($data)
    {
    # Ponctuation et mots recurents
    $data=~s/[\s\t]+/ /gm;
    $data=~s/http:\/\// /gm;
    $data=~tr/.;:,?!()\"\'[]#=\/_/ /;
    my @ex = split(/\s/,$data);
    foreach my $e (@ex)
      {
      next if !$e;
      $e=lc($e);
      if (($e =~/\w/)&&(length($e)>2)&&(!$bad{$e})) {$l{$e}+=$facteur;}
      }
    }
  return \%l;
  }

#------------------------------------------------------------------------------
# check_links
#------------------------------------------------------------------------------
sub check_links
  {
    my($self,$tag,$links) = @_;
    my $host = $self->{INDEXER}->host_indexed;
    my $bad = qr/\.(doc|zip|ps|gif|jpg|gz|pdf|eps|png|deb|xls|ppt|
		    class|GIF|css|js|wav|mid)$/i;
    if (($tag) && ($links) && ($tag eq 'a') 
	&& ($links=~/$host/) 
	&& ($links !~ $bad))
    {
      if ($links=~/^(.*?)#/) {$links=$1;} # Don't add anchor
      if ((!$self->{ConfigMoteur}->{'indexCgi'})&&($links=~/^(.*?)\?/)) 
	  {$links=$1;}
      return $links;
    }
   return 0;
  }

#------------------------------------------------------------------------------
# POD DOCUMENTATION
#------------------------------------------------------------------------------

=head1 NAME

Circa::Parser - provide functions to parse HTML pages by Circa

=head1 SYNOPSIS

      use Circa::Indexer;
      my $index = new Circa::Indexer;
      $index->connect(...);
      #$index->Parser->look_at($url,account);

=head1 DESCRIPTION

This module use HTML::Parser facilities. It's call by Circa::Indexer
for index each document. Main method is C<look_at>.

=head1 VERSION

$Revision: 1.8 $

=head1 Public Class Interface

=over

=item new($indexer_instance)

Create a new Circa::Parser object with indexer instance properties

=item tag

Method call for each HTML tag find in HTML pages.

=item text

Method call for each content of tag in HTML pages

=item look_at ($url,$idc,$idr,$lastModif,$url_local,
               $categorieAuto,$niveau,$categorie)

Index an url. Job done is:

=over

=item *

Test if url used is valid. Return -1 else

=item *

Get the page and add each words found with weight set in constructor.

=item *

If maximum level of links is not reach, add each link found for the next 
indexation

=back

Parameters:

=over

=item *

$url : Url to read

=item *

$idc: Id of url in table links

=item *

$idr : Id of account's url

=item *

$lastModif (optional) : If this parameter is set, Circa didn't make any job
on this page if it's older that the date.

=item *

$url_local (optional) Local url to reach the file

=item *

$categorieAuto (optional) If $categorieAuto set to true, Circa will
create/set the category of url with syntax of directory found. Ex:

http://www.alianwebserver.com/societe/stvalentin/index.html will create
and set the category for this url to Societe / StValentin

If $categorieAuto set to false, $categorie will be used.

=item *

$niveau (optional) Level of actual link.

=item *

$categorie (optional) See $categorieAuto.

=back

Return (-1,0) if url isn't valide, number of word and number of links  
found else

=item set_agent($locale)

Set user agent for Circa robot. If $locale is ==0 or 
$self->{ConfigMoteur}->{'temporate'}==0,
LWP::UserAgent will be used. Else LWP::RobotUA is used.

=item analyse($data,$facteur,%l)

Recupere chaque mot du buffer $data et lui attribue une frequence d'apparition.
Les resultats sont ranges dans le tableau associatif passé en paramètre.
Les résultats sont rangés sous la forme %l=('mots'=>facteur).

=over

=item *

$data : buffer à analyser

=item *

$facteur : facteur à attribuer à chacun des mots trouvés

=item *

%l : Tableau associatif où est rangé le résultat

=back

Retourne la référence vers le hash

=item check_links($tag,$links)

Check if url $links will be add to Circa. Url must begin with 
$self->host_indexed, and his extension must be not doc,zip,ps,gif,jpg,gz,
pdf,eps,png,deb,xls,ppt,class,GIF,css,js,wav,mid.

If $links is accepted, return url. Else return 0.

=back

=head1 AUTHOR

Alain BARBET alian@alianwebserver.com

=cut
