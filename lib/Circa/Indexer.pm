package Circa::Indexer;

# module Circa::Indexer : provide function to administrate Circa
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.

# $Log: Indexer.pm,v $
# Revision 1.21  2001/08/01 19:41:11  alian
# - Add return code for method connect : now you'll see if Indexer can connect
# or not
#
# Revision 1.20  2001/05/28 18:41:18  alian
# - Move Parser method from Circa.pm to Indexer.pm
#
# Revision 1.19  2001/05/23 10:34:01  alian
# - Remove some close_connect call in export/import method
#
# Revision 1.18  2001/05/21 22:47:40  alian
# - Remove some method use in Search and Indexer and build a father class : Circa.pm
#
# Revision 1.17  2001/05/20 12:12:43  alian
# - Use new URL->update and URL->add signature
#
# Revision 1.16  2001/05/15 23:01:14  alian
# - Use need_parser,  need_update and a_valider
#
# Revision 1.15  2001/05/14 23:25:42  alian
# - Use Circa::Url::non_valide method
# - Use /usr/bin/ before /usr/local/bin/ in export/import
#
# Revision 1.14  2001/05/14 22:14:32  alian
# - Update POD documentation
# - Correct bug in update routine
#
# Revision 1.13  2001/05/14 18:10:50  alian
# - Move POD documentation at end of file
# - Split code into multiple modules : Url, Categorie, Parser
#
# Revision 1.12  2001/03/31 19:07:40  alian
# - Update import and export functions: trouble with parameters,
# and add some control about file read/write
# - Update update method: use local url if present
# - Update set_agent call and usage

use strict;
use DBI;
use Circa;
use Circa::Parser;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
require Exporter;

@ISA = qw(Exporter Circa);
@EXPORT = qw();
$VERSION = ('$Revision: 1.21 $ ' =~ /(\d+\.\d+)/)[0];

########## CONFIG  ##########
my %ConfigMoteurDefault=(
  'author'    => 'circa@alianwebserver.com', # Responsable du moteur
  'temporate'     => 1,  # Temporise les requetes sur le serveur de 8s.
  'facteur_keyword'  => 15, # <meta name="KeyWords"
  'facteur_description'  => 10, # <meta name="description"
  'facteur_titre'    => 10, # <title></title>
  'facteur_full_text'  => 1,  # reste
  'facteur_url' => 15, # Mots trouvés dans l'url
  'nb_min_mots'    => 2,  # facteur min pour garder un mot
  'niveau_max'    => 7,  # Niveau max à indexer
  'indexCgi'    => 0,  # Suit les différents liens des CGI (ex: ?nom=toto&riri=eieiei)
  );
########## FIN CONFIG  ##########

#------------------------------------------------------------------------------
# new
#------------------------------------------------------------------------------
sub new 
  {
    my $class = shift;
    my $self = $class->SUPER::new;
    bless $self, $class;
    $self->{SIZE_MAX}     = 1000000;  # Size max of file read
    $self->{HOST_INDEXED} = undef;
    $self->{PROXY} = undef;
    $self->{ConfigMoteur} = \%ConfigMoteurDefault;
    if (@_)
      {
	my %vars =@_;
	while (my($n,$v)= each (%vars)) {$self->{'ConfigMoteur'}->{$n}=$v;}
      }
    return $self;
  }

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub connect 
  { 
    my $self=shift;
    $self->{PARSER} = Circa::Parser->new($self);
    return $self->SUPER::connect(@_);
  }

#------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------
sub Parser { return $_[0]->{PARSER}; }

#------------------------------------------------------------------------------
# size_max
#------------------------------------------------------------------------------
sub size_max
  {
  my $self = shift;
  if (@_) {$self->{SIZE_MAX}=shift;}
  return $self->{SIZE_MAX};
  }

#------------------------------------------------------------------------------
# host_indexed
#------------------------------------------------------------------------------
sub host_indexed
  {
  my $self = shift;
  if (@_) {$self->{HOST_INDEXED}=shift;}
  return $self->{HOST_INDEXED};
  }

#------------------------------------------------------------------------------
# set_host_indexed
#------------------------------------------------------------------------------
sub set_host_indexed
  {
  my $this=shift;
  my $url=$_[0];
  if ($url=~/^(http:\/\/.*?)\/$/) {$this->host_indexed($1);}
  elsif ($url=~/^(http:\/\/.*?)\/[^\/]+$/) {$this->host_indexed($1);}
  elsif ($url=~/^(file:\/\/\/[^\/]*)\//) {$this->host_indexed($1);}
  else {$this->host_indexed($url);}
  }

#------------------------------------------------------------------------------
# proxy
#------------------------------------------------------------------------------
sub proxy
  {
  my $self = shift;
  if (@_) {$self->{PROXY}=shift;}
  return $self->{PROXY};
  }

#------------------------------------------------------------------------------
# addSite
#------------------------------------------------------------------------------
sub addSite
  {
    my ($self,$url,$email,$titre,$categorieAuto,$cgi,$rep,$file)=@_;
    #print "$url,$email,$titre,$categorieAuto,$cgi,$rep,$file\n";
    if ($cgi)
      {
	$file=$cgi->param('file');
	my $tmpfile=$cgi->tmpFileName($file); # chemin du fichier temp
	if ($file=~/.*\\(.*)$/) {$file=$1;}
	my $fileC=$file;
	$file = $rep.$file;
	use File::Copy;
	copy($tmpfile,$file) 
	  || die "Impossible de creer $file avec $tmpfile:$!\n<br>";
      }
    if (!$email) {$email='Inconnu';}
    if (!$titre) {$titre='Non fourni';}
    if (!$file) {$file=' ';}
    if (!$categorieAuto) {$categorieAuto=0;}
    my $sth = $self->{DBH}->prepare("
         insert into ".$self->pre_tbl."responsable
                   (email,titre,categorieAuto,masque) 
         values ('$email','$titre',$categorieAuto,'$file')");
  $sth->execute || print "Erreur: $DBI::errstr<br>\n";
  $sth->finish;
  $self->create_table_circa_id($sth->{'mysql_insertid'});
  $self->URL->add($sth->{'mysql_insertid'},(url => $url, valide =>1))
    || print $DBI::errstr,"\n";
  return $sth->{'mysql_insertid'};
  }

#------------------------------------------------------------------------------
# addLocalSite
#------------------------------------------------------------------------------
sub addLocalSite
  {
    my ($self,$url,$email,$titre,$local_url,$path,$urlRacine,
	$categorieAuto,$cgi,$rep,$file)=@_;
    if ($cgi)
      {
	$file=$cgi->param('file');
	my $tmpfile=$cgi->tmpFileName($file); # chemin du fichier temp
	if ($file=~/.*\\(.*)$/) {$file=$1;}
	my $fileC=$file;
	$file = $rep.$file;
	use File::Copy;
	copy($tmpfile,$file) 
	  || die "Impossible de creer $file avec $tmpfile:$!\n<br>";
      }
    my $sth = $self->{DBH}->prepare("
              insert into ".$self->pre_tbl."responsable
                  (email,titre,categorieAuto) 
              values('$email','$titre',$categorieAuto)");
    $sth->execute;
    $sth->finish;
    my $id = $sth->{'mysql_insertid'};
    $self->{DBH}->do("insert into ".$self->pre_tbl."local_url 
                      values($id,'$urlRacine','$path');");
    $self->create_table_circa_id($sth->{'mysql_insertid'});
  $self->URL->add($id,(url=> $url, local_url => $local_url, valide=>1)) 
    || print "Erreur: $DBI::errstr<br>\n";
  }

#------------------------------------------------------------------------------
# parse_new_url
#------------------------------------------------------------------------------
sub parse_new_url
  {
    my ($self,$idp)=@_; 
    print "Indexer::parse_new_url\n" if ($self->{DEBUG});
    my ($nb,$nbAjout,$nbWords,$nbWordsGood)=(0,0,0,0);
    my $tab = $self->URL->need_parser($idp);
    my $categorieAuto = $self->categorie->auto($idp);
    foreach my $id (keys %$tab) 
      {
	my ($url,$local_url,$niveau,$categorie,$lu)=$$tab{$id};
	my ($res,$nbw,$nbwg) = 
	  $self->Parser->look_at
	    (
	     $$tab{$id}[0],$id,$idp,				 
	     ($$tab{$id}[4]||undef), 
	     ($$tab{$id}[1]||undef),				 
	     $categorieAuto, $$tab{$id}[2], $$tab{$id}[3]);
	if ($res==-1) {$self->URL->non_valide($idp,$id);}
	else {$nbAjout+=$res;$nbWords+=$nbw;$nb++;$nbWordsGood+=$nbwg;}
      }  
    return ($nb,$nbAjout,$nbWords,$nbWordsGood);
  }


#------------------------------------------------------------------------------
# update
#------------------------------------------------------------------------------
sub update
  {
    my ($this,$xj,$idp)=@_;
    $idp = 1 if (!$idp);
    $this->parse_new_url($idp);  
    my ($nb,$nbAjout,$nbWords,$nbWordsGood)=(0,0,0,0);
    my $tab = $this->URL->need_update($idp,$xj);
    my $categorieAuto = $this->categorie->auto($idp);
    foreach my $id (keys %$tab) 
      {
	my ($url,$local_url,$niveau,$categorie,$lu) = $$tab{$id};
	my ($res,$nbw,$nbwg) = 
	  $this->Parser->look_at($$tab{$id}[0],$id,$idp,
				 $$tab{$id}[4] || undef, $$tab{$id}[1] ||undef,
				 $categorieAuto, $$tab{$id}[2], $$tab{$id}[3]);
	if ($res==-1) {$this->URL->non_valide($idp,$id);}
	else {$nbAjout+=$res;$nbWords+=$nbw;$nb++;$nbWordsGood+=$nbwg;}
      }
    return ($nb,$nbAjout,$nbWords,$nbWordsGood);
  }

#------------------------------------------------------------------------------
# create_table_circa
#------------------------------------------------------------------------------
sub create_table_circa
  {
  my $self = shift;
  my $requete="
CREATE TABLE ".$self->pre_tbl."responsable (
   id     int(11) DEFAULT '0' NOT NULL auto_increment,
   email  char(25) NOT NULL,
   titre  char(50) NOT NULL,
   categorieAuto tinyint DEFAULT '0' NOT NULL,
   masque  char(150) NOT NULL,
   PRIMARY KEY (id)
)";

  $self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";
  $requete="
CREATE TABLE ".$self->pre_tbl."inscription (
   email  char(25) NOT NULL,
   url     varchar(255) NOT NULL,
   titre  char(50) NOT NULL,
   dateins  date
)";
  $self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";

  $requete="
CREATE TABLE ".$self->pre_tbl."local_url (
   id  int(11)     NOT NULL,
   path  varchar(255) NOT NULL,
   url  varchar(255) NOT NULL
)";
  $self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";
  }

#------------------------------------------------------------------------------
# drop_table_circa
#------------------------------------------------------------------------------
sub drop_table_circa
  {
  my $self = shift;
  my $sth = $self->{DBH}->prepare
    ("select id from ".$self->pre_tbl."responsable");
  $sth->execute() || print $self->header,$DBI::errstr,"<br>\n";
  while (my @row=$sth->fetchrow_array) {$self->drop_table_circa_id($row[0]);}
  $sth->finish;
  $self->{DBH}->do("drop table ".$self->pre_tbl."responsable")
    || print $DBI::errstr,"<br>\n";
  $self->{DBH}->do("drop table ".$self->pre_tbl."inscription") 
    || print $DBI::errstr,"<br>\n";
  $self->{DBH}->do("drop table ".$self->pre_tbl."local_url")  
    || print $DBI::errstr,"<br>\n";
  }

#------------------------------------------------------------------------------
# drop_table_circa_id
#------------------------------------------------------------------------------
sub drop_table_circa_id
  {
  my $self = shift;
  my $id=$_[0];
  $self->{DBH}->do("drop table ".$self->pre_tbl.$id."categorie")  
    || print $DBI::errstr,"<br>\n";
  $self->{DBH}->do("drop table ".$self->pre_tbl.$id."links")      
    || print $DBI::errstr,"<br>\n";
  $self->{DBH}->do("drop table ".$self->pre_tbl.$id."relation")   
    || print $DBI::errstr,"<br>\n";
  $self->{DBH}->do("drop table ".$self->pre_tbl.$id."stats")      
    || print $DBI::errstr,"<br>\n";
  $self->{DBH}->do
    ("delete from ".$self->pre_tbl."responsable where id=$id");
  }

#------------------------------------------------------------------------------
# create_table_circa_id
#------------------------------------------------------------------------------
sub create_table_circa_id
  {
  my $self = shift;
  my $id=$_[0];
  my $requete="
CREATE TABLE ".$self->pre_tbl.$id."categorie (
   id     int(11) DEFAULT '0' NOT NULL auto_increment,
   nom     char(50) NOT NULL,
   parent   int(11) DEFAULT '0' NOT NULL,
   masque varchar(255),
   PRIMARY KEY (id)
   )";
  $self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";

  $requete="
CREATE TABLE ".$self->pre_tbl.$id."links (
   id     int(11) DEFAULT '0' NOT NULL auto_increment,
   url     varchar(255) NOT NULL,
   local_url   varchar(255),
   titre   varchar(255) NOT NULL,
   description   blob NOT NULL,
   langue   char(6) NOT NULL,
   valide   tinyint DEFAULT '0' NOT NULL,
   categorie   int(11) DEFAULT '0' NOT NULL,
   last_check   datetime DEFAULT '0000-00-00' NOT NULL,
   last_update  datetime DEFAULT '0000-00-00' NOT NULL,
   parse   ENUM('0','1') DEFAULT '0' NOT NULL,
   browse_categorie ENUM('0','1') DEFAULT '0' NOT NULL,
   niveau   tinyint DEFAULT '0' NOT NULL,
   PRIMARY KEY (id),
   KEY id (id),
   UNIQUE id_2 (id),
   KEY id_3 (id),
   KEY url (url),
   UNIQUE url_2 (url),
   KEY categorie (categorie)
)";
  $self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";

  $requete="
CREATE TABLE ".$self->pre_tbl.$id."relation (
   mot     char(30) NOT NULL,
   id_site   int(11) DEFAULT '0' NOT NULL,
   facteur   tinyint(4) DEFAULT '0' NOT NULL,
   KEY mot (mot)
)";
  $self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";
  $requete="
CREATE TABLE ".$self->pre_tbl.$id."stats (
   id  int(11) DEFAULT '0' NOT NULL auto_increment,
   requete varchar(255) NOT NULL,
   quand datetime NOT NULL,
   PRIMARY KEY (id)
)";
  $self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";
  }

#------------------------------------------------------------------------------
# export
#------------------------------------------------------------------------------
sub export
  {
  my ($self,$dump,$path)=@_;
  my ($pass,$file);
  if (!$path) {use Cwd;$path=cwd;}
  $file=$path."/circa.sql";$file=~s/\/\//\//g;
  if ( (! -w $path) || ( ( -e $file) && (!-w $file)))  {$self->close; die "Can't create $file:$!\n";}
  if ( (!$dump) || (! -x $dump))
    {
    if (-x "/usr/bin/mysqldump") {$dump = "/usr/bin/mysqldump" ;}
    elsif (-x "/usr/local/bin/mysqldump"){$dump = "/usr/local/bin/mysqldump";}
    elsif (-x "/opt/bin/mysqldump") {$dump = "/opt/bin/mysqldump" ;}
    else {$self->close; die "Can't find mysqldump.\n";}
    }
  unlink $file;
  my (@t,@exec);
  my $requete = "select id from ".$self->pre_tbl."responsable";
  my $sth = $self->{DBH}->prepare($requete);
  $sth->execute;
  while (my ($id)=$sth->fetchrow_array) {push(@t,$id);}
  $sth->finish;
  if ($self->{_PASSWORD}) {$pass=" -p".$self->{_PASSWORD}.' ';}
  else {$pass=' ';}
  push(@exec,$dump." --add-drop-table -u".$self->{_USER}.$pass.$self->{_DB}." ".$self->pre_tbl."responsable >> $file");
  push(@exec,$dump." --add-drop-table  -u".$self->{_USER}.$pass.$self->{_DB}." ".$self->pre_tbl."local_url >> $file");
  push(@exec,$dump." --add-drop-table  -u".$self->{_USER}.$pass.$self->{_DB}." ".$self->pre_tbl."inscription >> $file");
  foreach my $id (@t)
    {
    push(@exec,$dump." --add-drop-table -u".$self->{_USER}.$pass.$self->{_DB}." ".$self->pre_tbl.$id."categorie >> $file");
    push(@exec,$dump." --add-drop-table -u".$self->{_USER}.$pass.$self->{_DB}." ".$self->pre_tbl.$id."links >> $file");
    push(@exec,$dump." --add-drop-table -u".$self->{_USER}.$pass.$self->{_DB}." ".$self->pre_tbl.$id."relation >> $file");
    #push(@exec,$dump." --add-drop-table -u".$self->{_USER}.$pass.$self->{_DB}." ".$self->pre_tbl.$id."stats >> $file");
    }
  $|=1;
  print "En cours d'export ...";
  foreach (@exec) {system($_) ==0 or print "Fail:$?-$!\n";}
  print "$file done.\n";
  }


#------------------------------------------------------------------------------
# import_data
#------------------------------------------------------------------------------
sub import_data
  {
  my ($self,$dump,$path)=@_;
  my ($pass,$file);
  if (!$path) {use Cwd;$path=cwd;}
  $file=$path."/circa.sql";$file=~s/\/\//\//g;
  if (! -r $file) {$self->close; die "Can't find $file:$!\n";}
  if ( (!$dump) || (! -x $dump))
    {
    if (-x "/usr/bin/mysql") {$dump = "/usr/bin/mysql" ;}
    elsif (-x "/usr/local/bin/mysql") {$dump = "/usr/local/bin/mysql" ;}
    elsif (-x "/opt/bin/mysql") {$dump = "/opt/bin/mysql" ;}
    else {$self->disconnect; die "Can't find mysql.\n";}
    }
  $|=1;
  print "En cours d'import ...";
  my $c = $dump." -u".$self->{_USER};
  $c.=" -p".$self->{_PASSWORD} if ($self->{_PASSWORD});
  $c.=" ".$self->{_DB}." < ".$file;
  system($c) == 0 or print "Fail:$c:$?\n";
  print "$file imported.\n";
  }

#------------------------------------------------------------------------------
# admin_compte
#------------------------------------------------------------------------------
sub admin_compte
  {
  my ($self,$compte)=@_;
  my %rep;
  my $pre = $self->pre_tbl.$compte;
  ($rep{'responsable'},$rep{'titre'}) = 
    $self->fetch_first("select email,titre from ". $self->pre_tbl.
		     "responsable where id=$compte");
  # there is no account $compte defined
  if (!$rep{'responsable'}) {return (undef);}
  # First url added
  ($rep{'racine'})=$self->fetch_first("select min(id) from ".$pre."links");
  ($rep{'racine'})=$self->fetch_first("select url from ".$pre."links ".
				  "where id=".$rep{'racine'});
  # Number of links
  ($rep{'nb_links'}) = $self->fetch_first("select count(1) from ".$pre."links");
  # Number of parsed links
  ($rep{'nb_links_parsed'}) =
    $self->fetch_first("select count(1) from ".$pre."links where parse='1'");
  # Number of parsed valid links
  ($rep{'nb_links_valide'}) =
    $self->fetch_first("select count(1) from ".$pre."links ".
		     "where parse='1' and valide ='1'");
  # Max depth reached
  $rep{'depth_max'} = $self->fetch_first("select max(niveau) ".
					 "from ".$pre."links");
  # Account last indexed on
  ($rep{'last_index'}) = 
    $self->fetch_first("select max(last_check) from ".$pre."links");
  # Stats ... how many request ?
  ($rep{'nb_request'}) = 
    $self->fetch_first("select count(1) from ".$pre."stats");
  # Number of word
  ($rep{"nb_words"}) = 
    $self->fetch_first("select count(1) from ".$pre."relation");
  # Return reference of hash
  return \%rep;
  }


#------------------------------------------------------------------------------
# most_popular_word
#------------------------------------------------------------------------------
sub most_popular_word
  {
  my $self = shift;
  my ($max,$id)=@_;
  $id =1 if (!$id);
  my %l;
  my $requete = "select mot,count(1) from ".
    $self->pre_tbl.$id."relation r group by r.mot order by 2 ".
      "desc limit 0,$max";
  my $sth = $self->{DBH}->prepare($requete);
  $sth->execute;
  while (my ($word,$nb)=$sth->fetchrow_array) {$l{$word}=$nb;}
  $sth->finish;
  return \%l;
  }


#------------------------------------------------------------------------------
# stat_request
#------------------------------------------------------------------------------
sub stat_request
  {
  my ($self,$id)=@_;
  my (%l1,%l2);
  my $requete = "select count(1), DATE_FORMAT(quand, '%e/%m/%y') as d ".
    "from ".$self->pre_tbl.$_[1]."stats group by d order by d";
  my $sth = $self->{DBH}->prepare($requete);
  $sth->execute;
  while (my ($nb,$word)=$sth->fetchrow_array) {$l1{$word}=$nb;}
  $sth->finish;

  $requete = "select requete,count(requete) ".
    "from ".$self->pre_tbl.$_[1]."stats ".
    "group by 1 order by 2 desc limit 0,10";
  $sth = $self->{DBH}->prepare($requete);
  $sth->execute;
  while (my ($word,$nb)=$sth->fetchrow_array) {$l2{$word}=$nb;}
  $sth->finish;

  return (\%l1,\%l2);
  }

#------------------------------------------------------------------------------
# inscription
#------------------------------------------------------------------------------
sub inscription {$_[0]->do("insert into ".$_[0]->pre_tbl."inscription values ('$_[1]','$_[2]','$_[3]',CURRENT_DATE)");}


#------------------------------------------------------------------------------
# header_compte
#------------------------------------------------------------------------------
sub header_compte
  {
  my ($self,$cgi,$id,$script)=@_;
  my $v = "<a href=\"$script?compte=$id";
  my $buf='<ul>'."\n".
   $cgi->li($v."\">Infos générales</a>")."\n" .
   $cgi->li($v."&ecran_stats=1\">Statistiques</a>")."\n".
   $cgi->li($v."&ecran_urls=1\">Gestion des url</a>")."\n".
   $cgi->li($v."&&ecran_validation=1\">Validation des url</a>")."\n".
   $cgi->li($v."&ecran_categorie=1\">Gestion des categories</a>")."\n".
    '</ul>'."\n";
  return $buf;
  }

#------------------------------------------------------------------------------
# Get_liste_liens
#------------------------------------------------------------------------------
sub get_liste_liens
  {
    my ($self,$id,$cgi)=@_;
    my $tab = $self->URL->liens($id);
    my @l =sort { $$tab{$a} cmp $$tab{$b} } keys %$tab;
    return $cgi->scrolling_list(  -'name'=>'id',
				  -'values'=>\@l,
				  -'size'=>1,
				  -'labels'=>$tab);
  }

#------------------------------------------------------------------------------
# get_liste_liens_a_valider
#------------------------------------------------------------------------------
sub get_liste_liens_a_valider
  {
  my ($self,$id,$cgi)=@_;  
  my $tab = $self->URL->a_valider($id);
  my $buf='<table>';
  my @l =sort { $$tab{$a} cmp $$tab{$b} } keys %$tab;
  foreach (@l)  
    {
      $buf.=$cgi->Tr(
	 $cgi->td("<input type=\"radio\" name=\"id\" value=\"$_\">"),
	 $cgi->td("<a target=_blank href=\"$$tab{$_}\">$$tab{$_}</a>")
		    )."\n";
    }
  $buf.='</table>';
  return $buf;
}

#------------------------------------------------------------------------------
# get_liste_site
#------------------------------------------------------------------------------
sub get_liste_site
  {
  my ($self,$cgi)=@_;
  my %tab;
  my $sth = $self->{DBH}->prepare("select id,email,titre from ".$self->pre_tbl."responsable");
  $sth->execute() || print &header,$DBI::errstr,"<br>\n";
  while (my @row=$sth->fetchrow_array) {$tab{$row[0]}="$row[1]/$row[2]";}
  $sth->finish;
  my @l =sort { $tab{$a} cmp $tab{$b} } keys %tab;
  return $cgi->scrolling_list(  -'name'=>'id',
                             -'values'=>\@l,
                             -'size'=>1,
                             -'labels'=>\%tab);
        }

#------------------------------------------------------------------------------
# get_liste_mot
#------------------------------------------------------------------------------
sub get_liste_mot
  {
  my ($self,$compte,$id)=@_;
  my @l;
  my $sth = $self->{DBH}->prepare("select mot from ".$self->pre_tbl.$compte."relation where id_site=$id");
  $sth->execute() || print "Erreur: $DBI::errstr\n";
  while (my ($l)=$sth->fetchrow_array) {push(@l,$l);}
  return join(' ',@l);
  }

#------------------------------------------------------------------------------
# get_liste_langues
#------------------------------------------------------------------------------
sub get_liste_langues
  {
  my ($self,$id,$valeur,$cgi)=@_;
  my @l;
  my $sth = $self->{DBH}->prepare("select distinct langue ".
				  "from ".$self->pre_tbl.$id."links");
  $sth->execute() || print "Erreur: $DBI::errstr\n";
  while (my ($l)=$sth->fetchrow_array) {push(@l,$l);}
  $sth->finish;
  my %langue=(
	      'unkno'=>'unkno',
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
    $cgi->scrolling_list(  -'name'=>'langue',
                             -'values'=>\@l,
                             -'size'=>1,
                             -'default'=>$valeur,
                             -'labels'=>\%langue);
  }

#------------------------------------------------------------------------------
# POD DOCUMENTATION
#------------------------------------------------------------------------------

=head1 NAME

Circa::Indexer - provide functions to administrate Circa,
a www search engine running with Mysql

=head1 SYNOPSIS

 use Circa::Indexer;
 my $indexor = new Circa::Indexer;

 if (!$indexor->connect_mysql($user,$pass,$db))
  {die "Erreur à la connection MySQL:$DBI::errstr\n";}

 $indexor->create_table_circa;

 $indexor->drop_table_circa;

 $indexor->addSite("http://www.alianwebserver.com/",
                   'alian@alianwebserver.com',
                   "Alian Web Server");

 my ($nbIndexe,$nbAjoute,$nbWords,$nbWordsGood) = $indexor->parse_new_url(1);
 print   "$nbIndexe pages indexées,"
   "$nbAjoute pages ajoutées,"
   "$nbWordsGood mots indexés,"
   "$nbWords mots lus\n";

 $indexor->update(30,1);

Look in admin.pl,admin.cgi,admin_compte.cgi

=head1 DESCRIPTION

This is Circa::Indexer, a module who provide functions
to administrate Circa, a www search engine running with
Mysql. Circa is for your Web site, or for a list of sites.
It indexes like Altavista does. It can read, add and
parse all url's found in a page. It add url and word
to MySQL for use it at search.

This module provide routine to :

=over

=item *

Add url

=item *

Create and update each account

=item *

Parse url, Index words, and so on.

=item *

Provide routine to administrate present url

=back

Remarques:

=over

=item *

This file are not added : doc,zip,ps,gif,jpg,gz,pdf,eps,png,
deb,xls,ppt,class,GIF,css,js,wav,mid

=item *

Weight for each word is in hash $ConfigMoteur

=back

=head2 Features ?

Features

=over

=item *

Search Features

=over

=item *

Boolean query language support : or (default) and ("+") not ("-"). Ex perl + faq -cgi :
Documents with faq, eventually perl and not cgi.

=item *

Client Perl or PHP

=item *

Can browse site by directory / rubrique.

=item *

Search for different criteria: news, last modified date, language, URL / site.

=back

=item *

Full text indexing

=item *

Different weights for title, keywords, description and rest of page HTML read can be given in configuration

=item *

Herite from features of LWP suite:

=over

=item *

Support protocol HTTP://,FTP://, FILE:// (Can do indexation of filesystem without talk to Web Server)

=item *

Full support of standard robots exclusion (robots.txt). Identification with
CircaIndexer/0.1, mail alian@alianwebserver.com. Delay requests to
the same server for 8 secondes. "It's not a bug, it's a feature!" Basic
rule for HTTP serveur load.

=item *

Support proxy HTTP.

=back

=item *

Make index in MySQL

=item *

Read HTML and full text plain

=item *

Several kinds of indexing : full, incremental, only on a particular server.

=item *

Documents not updated are not reindexed.

=item *

All requests for a file are made first with a head http request, for information
such as validate, last update, size, etc.Size of documents read can be
restricted (Ex: don't get all documents > 5 MB). For use with low-bandwidth
connections, or computers which do not have much memory.

=item *

HTML template can be easily customized for your needs.

=item *

Admin functions available by browser interface or command-line.

=item *

Index the different links found in a CGI (all after name_of_file?)

=back

=head2 How it's work ?

Circa parse html document. convert it to text. It count all
word found and put result in hash key. In addition of that,
it read title, keywords, description and add a weight to
all word found.

Example:
 my %ConfigMoteur=(
  'author'              => 'circa@alianwebserver.com', # Responsable du moteur
  'temporate'           => 1,  # Temporise les requetes sur le serveur de 8s.
  'facteur_keyword'     => 15, # <meta name="KeyWords"
  'facteur_description' => 10, # <meta name="description"
  'facteur_titre'       => 10, # <title></title>
  'facteur_full_text'   => 1,  # reste
  'facteur_url'         => 15, # Mots trouvés dans l'url
  'nb_min_mots'         => 2,  # facteur min pour garder un mot
  'niveau_max'          => 7,  # Niveau max à indexer
  'indexCgi'            => 0,  # Index lien des CGI (ex: ?nom=toto&riri=eieiei)
  );

 <html>
 <head>
 <meta name="KeyWords"
       CONTENT="informatique,computing,javascript,CGI,perl">
 <meta name="Description" 
       CONTENT="Rubriques Informatique (Internet,Java,Javascript, CGI, Perl)">
 <title>Alian Web Server:Informatique,Société,Loisirs,Voyages</title>
 </head>
 <body>
 different word: cgi, perl, cgi
 </body>
 </html>

After parsing I've a hash with that:

 $words{'informatique'}= 15 + 10 + 10 =35
 $words{'cgi'} = 15 + 10 +1
 $words{'different'} = 1

Words is add to database if total found is > $ConfigMoteur{'nb_min_mots'}
(2 by default). But if you set to 1, database will grow very quicly but
allow you to perform very exact search with many worlds so you can do phrase
searches. But if you do that, think to take a look at size of table
relation.

After page is read, it's look into html link. And so on. At each time, the level
grow to one. So if < to $Config{'niveau_max'}, url is added.

=head1 VERSION

$Revision: 1.21 $

=head1 Class Interface

=head2 Constructors and Instance Methods

=over

=item new    [PARAMHASH]

You can use the following keys in PARAMHASH:

=over

=item author

Default: 'circa@alianwebserver.com', appear in log file of web server indexed (as agent)

=item  temporate

Default: 1,  boolean. If true, wait 8s between request on same server and
LWP::RobotUA will be used. Else this is LWP::UserAgent (more quick because it
doesn't request and parse robots.txt rules, but less clean because a robot must always
say who he is, and heavy server load is avoid).

=item facteur_keyword

Default: 15, weight of word found on meta KeyWords

=item facteur_description

Default:10, weight of word found on meta description"

=item facteur_titre

Default:10, weight of word found on  <title></title>

=item facteur_full_text

Default:1,  weight of word found on rest of page

=item facteur_url

Default: 15, weight of word found in url

=item nb_min_mots

Default: 2, minimal number of times a word must be found to be added

=item niveau_max

Default: 7, Maximal number of level of links to follow

=item indexCgi

Default 0, follow of not links of CGI (ex: ?nom=toto&riri=eieiei)

=back

=item size_max($size)

Get or set size max of file read by indexer (For avoid memory pb).

=item host_indexed($host)

Get or set the host indexed.

=item set_host_indexed($url)

Set base directory with $url. It's used for restrict access
only to files found on sub-directory on this serveur.

=item proxy($adr_proxy)

Get or set proxy for LWP::Robot or LWP::Agent

Ex: $circa->proxy('http://proxy.sn.no:8001/');

=back

=head2 Methods use for global adminstration

=over

=item addSite($url,$email,$titre,$categorieAuto,$cgi,$rep,$file);

Ajoute le site d'url $url, responsable d'adresse mail $email à la bd de Circa
Retourne l'id du compte cree

Create account for url $url. Return id of account created.


=item addLocalSite($url,$email,$titre,$local_url,$path,
                   $urlRacine,$categorieAuto,$cgi,$rep,$file);

Add a local $url

=item parse_new_url($idp)

Parse les pages qui viennent d'être ajoutée. Le programme va analyser toutes
les pages dont la colonne 'parse' est égale à 0.

Retourne le nombre de pages analysées, le nombre de page ajoutées, le
nombre de mots indexés.

=item update($xj,[$idp])

Update url not visited since $xj days for account $idp. If idp is not
given, 1 will be used. Url never parsed will be indexed.

Return ($nb,$nbAjout,$nbWords,$nbWordsGood)

=over

=item *

$nb: Number of links find

=item  *

$nbAjout: Number of links added

=item *

$nbWords: Number of word find

=item *

$nbWordsGood: Number of word added

=back

=cut

=item create_table_circa

Create tables needed by Circa - Cree les tables necessaires à Circa:

=over

=item *

categorie   : Catégories de sites

=item *

links       : Liste d'url

=item *

responsable : Lien vers personne responsable de chaque lien

=item *

relations   : Liste des mots / id site indexes

=item *

inscription : Inscriptions temporaires

=back

=cut

=item drop_table_circa

Drop all table in Circa ! Be careful ! - Detruit touted les tables de Circa

=cut

=item drop_table_circa_id($id)

Detruit les tables de Circa pour l'utilisateur $id

=cut

=item create_table_circa_id($id)

Create tables needed by Circa for instance $id:

=over

=item *

categorie   : Catégories de sites

=item *

links       : Liste d'url

=item *

relations   : Liste des mots / id site indexes

=item *

stats   : Liste des requetes

=back

=item export([$mysqldump], [$path])

Export data from Mysql in $path/circa.sql

$mysqldump: path of bin of mysqldump. If not given, search in /usr/bin/mysqldump,
/usr/local/bin/mysqldump, /opt/bin/mysqldump.

$path: path of directory where circa.sql will be created. If not given,
create it in current directory.

=item import_data([$mysql], [$path])

Import data in Mysql from circa.sql

$mysql : path of bin of mysql. If not given, search in /usr/bin/mysql,
/usr/local/bin/mysql, /opt/bin/mysql

$path: path of directory where circa.sql will be read. If not given,
read it from current directory.

=back

=head2 Method for administrate each account

=over

=item admin_compte($compte)

Return list about account $compte

Retourne une liste d'elements se rapportant au compte $compte

=over

=item *

$responsable  : Adresse mail du responsable

=item *

$titre    : Titre du site pour ce compte

=item *

$nb_page  : Number of url added to Circa - Nombre de page pour ce site

=item *

$nb_words : Number of world added to Circa - Nombre de mots indexés

=item *

$last_index  : Date of last indexation. Date de la dernière indexation

=item *

$nb_requetes  : Number of request aked - Nombre de requetes effectuées sur ce site

=item *

$racine  : First page added - 1ere page inscrite

=back

=item most_popular_word($max,$id)

Retourne la reference vers un hash representant la liste
des $max mots les plus présents dans la base de reponsable $id

=item stat_request($id)

Return some statistics about request make on Circa

=item inscription($email,$url,$titre)

Inscrit un site dans une table temporaire

=back

=head2 HTML functions

=over

=item header_compte

Function use with CGI admin_compte.cgi. Display list of features of 
admin_compte.cgi with this account

=item get_liste_liens($id)

Rend un buffer contenant une balise select initialisée avec les données
de la table links responsable $id

=item get_liste_liens_a_valider($id)

Rend un buffer contenant une balise select initialisée avec les données
de la table links responsable $id liens non valides

=item get_liste_site

Rend un buffer contenant une balise select initialisée avec les données
de la table responsable

=item get_liste_langues

Rend un buffer contenant une balise select initialisée avec les données
de la table responsable

=item get_liste_mot

Rend un buffer contenant une balise select initialisée avec les données
de la table responsable

=back

=head1 AUTHOR

Alain BARBET alian@alianwebserver.com

=cut
