use strict;
use warnings;
use CGI;
use DBI;
use JSON;
use Audio::TagLib;

my $cgi = CGI->new();
my $mp3Root = "/music";
my $imgRoot = "/music/.covers";
my $dbConn;

# set of (pl, gn, ar, al, sn)
# search of
#   gn ->
#   ar -> tags, note, genre
#   al -> artist, genre, year, tags, note
#   sn -> title, track, tags, note, ar, al, year, gn
#   pl -> title, tags, note, ar, al, sn, year, gn
#   ps -> plTitle

reqLibrary();

sub reqLibrary {
  # my @params = $cgi->param();
  if(!defined $cgi->param('qtype')) { textPlain(""); }
  if($cgi->param('qtype') eq 'total' ) { reqTotal (); }
  if($cgi->param('qtype') eq 'genre' ) { reqGenre (); }
  if($cgi->param('qtype') eq 'artist') { reqArtist(); }
  if($cgi->param('qtype') eq 'album' ) { reqAlbum (); }
  if($cgi->param('qtype') eq 'song'  ) { reqSong  (); }
}

sub reqTotal {
  my $q;
  my %obj;
  $dbConn = dbGet();
  $q = dbQuery("SELECT COUNT(*) FROM song"  ); $q->execute(); $obj{'songs'  } = $q->fetchrow_arrayref()->[0]; $q->finish();
  $q = dbQuery("SELECT COUNT(*) FROM album" ); $q->execute(); $obj{'albums' } = $q->fetchrow_arrayref()->[0]; # $q->finish();
  $q = dbQuery("SELECT COUNT(*) FROM artist"); $q->execute(); $obj{'artists'} = $q->fetchrow_arrayref()->[0]; $q->finish();
  textPlain(encode_json(\%obj));
}

sub reqGenre {
  $dbConn = dbGet();
  my $query = dbQuery("SELECT DISTINCT genre FROM artist"); $query->execute();
  my @arr;
  for(my $i=0; $i<$query->rows; $i++) {
    push(@arr, $query->fetchrow_arrayref()->[0]);
  }
  $query->finish();
  textPlain(encode_json(\@arr));
}

sub reqArtist {
  $dbConn = dbGet();
  my $query = "SELECT indexArtist, name, genre, tags, note FROM artist"; my $where=""; my @params;
  if(defined $cgi->param('tags'))  { $where.=" AND " if($where ne ""); $where.="(tags LIKE ?)"; push(@params, '%'. $cgi->param('tags') .'%'); }
  if(defined $cgi->param('note'))  { $where.=" AND " if($where ne ""); $where.="(note LIKE ?)"; push(@params, '%'. $cgi->param('note') .'%'); }
  if(defined $cgi->param('genre')) { $where.=" AND " if($where ne ""); $where.="(genre = ?)"  ; push(@params, $cgi->param('genre'));          }
  $query .= " WHERE " . $where if($where ne "");
  $query = dbQuery($query); $query->execute(@params);
  my @arr;
  for(my $i=0; $i<$query->rows; $i++) {
    my %obj; my $ref = $query->fetchrow_arrayref();
    $obj{'indexArtist'} = $ref->[0];
    $obj{'name'       } = $ref->[1];
    $obj{'genre'      } = $ref->[2];
    $obj{'tags'       } = $ref->[3];
    $obj{'note'       } = $ref->[4];
    push(@arr, \%obj);
  }
  $query->finish();
  textPlain(encode_json(\@arr));
}

sub reqAlbum {
  $dbConn = dbGet(); my @params;
  my $query = "SELECT artist.name, album.title, album.year, album.cover, album.tags, album.note";
  my $from  = " FROM album, artist";
  my $where = " WHERE (artist.indexArtist = album.indexArtist)";
  if(defined $cgi->param('artist')) { $where.=" AND " if($where ne ""); $where.="(artist.name = ?)"  ; push(@params, $cgi->param('artist')); }
  if(defined $cgi->param('genre' )) { $where.=" AND " if($where ne ""); $where.="(artist.genre = ?)" ; push(@params, $cgi->param('genre' )); }
  if(defined $cgi->param('year'  )) { $where.=" AND " if($where ne ""); $where.="(album.year = ?)"   ; push(@params, $cgi->param('year'  )); }
  if(defined $cgi->param('tags'  )) { $where.=" AND " if($where ne ""); $where.="(album.tags LIKE ?)"; push(@params, '%'. $cgi->param('tags') .'%'); }
  if(defined $cgi->param('note'  )) { $where.=" AND " if($where ne ""); $where.="(album.note LIKE ?)"; push(@params, '%'. $cgi->param('note') .'%'); }
  $query .= $from if($from ne "");
  $query .= $where if($where ne "");
  $query = dbQuery($query); $query->execute(@params);
  my @arr;
  for(my $i=0; $i<$query->rows; $i++) {
    my %obj; my $ref = $query->fetchrow_arrayref();
    $obj{'artist'    } = $ref->[0];
    $obj{'title'     } = $ref->[1];
    $obj{'year'      } = $ref->[2];
    $obj{'cover'     } = $ref->[3];
    $obj{'tags'      } = $ref->[4];
    $obj{'note'      } = $ref->[5];
    push(@arr, \%obj);
  }
  $query->finish();
  textPlain(encode_json(\@arr));
}

sub reqSong {
  $dbConn = dbGet(); my @params;
  my $query = "SELECT song.indexSong, artist.name, album.title, song.title, song.track, song.tags, song.note, album.year, artist.genre, song.file";
  my $from  = " FROM song, album, artist";
  my $where = " WHERE (song.indexAlbum = album.indexAlbum) AND (song.indexArtist = artist.indexArtist)";
  if(defined $cgi->param('index' )) { $where.=" AND " if($where ne ""); $where.="(song.indexSong = ?)"; push(@params, $cgi->param('index' )); }
  if(defined $cgi->param('artist')) { $where.=" AND " if($where ne ""); $where.="(artist.name = ?)"   ; push(@params, $cgi->param('artist')); }
  if(defined $cgi->param('album' )) { $where.=" AND " if($where ne ""); $where.="(album.title = ?)"   ; push(@params, $cgi->param('album' )); }
  if(defined $cgi->param('genre' )) { $where.=" AND " if($where ne ""); $where.="(artist.genre = ?)"  ; push(@params, $cgi->param('genre' )); }
  if(defined $cgi->param('year'  )) { $where.=" AND " if($where ne ""); $where.="(album.year = ?)"    ; push(@params, $cgi->param('year'  )); }
  if(defined $cgi->param('tags'  )) { $where.=" AND " if($where ne ""); $where.="(song.tags LIKE ?)"  ; push(@params, '%'. $cgi->param('tags' ) .'%'); }
  if(defined $cgi->param('note'  )) { $where.=" AND " if($where ne ""); $where.="(song.note LIKE ?)"  ; push(@params, '%'. $cgi->param('note' ) .'%'); }
  if(defined $cgi->param('title' )) { $where.=" AND " if($where ne ""); $where.="(song.title LIKE ?)" ; push(@params, '%'. $cgi->param('title') .'%'); }
  $query .= $from if($from ne "");
  $query .= $where if($where ne "");
  $query = dbQuery($query); $query->execute(@params);
  my @arr;
  for(my $i=0; $i<$query->rows; $i++) {
    my %obj; my $ref = $query->fetchrow_arrayref();
    $obj{'indexSong'} = $ref->[0];
    $obj{'artist'   } = $ref->[1];
    $obj{'album'    } = $ref->[2];
    $obj{'title'    } = $ref->[3];
    $obj{'track'    } = $ref->[4];
    $obj{'tags'     } = $ref->[5];
    $obj{'note'     } = $ref->[6];
    $obj{'year'     } = $ref->[7];
    $obj{'genre'    } = $ref->[8];
    $obj{'file'     } = $ref->[9];
    push(@arr, \%obj);
  }
  $query->finish();
  textPlain(encode_json(\@arr));
}

sub textPlain {
  my $content = shift;
  print "Content type: text/plain\r\n\r\n";
  print $content;
  exit 0;
}

sub dbQuery {
  my $id3=3;
  return $dbConn->prepare(shift);
}

sub dbGet {
  my $src  = "DBI:mysql:database=musicapp;host=localhost";
  my $conn = DBI->connect($src, "perldb", "----------"); # insert password
  
  return $conn;
}
