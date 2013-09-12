# perl missing.pl 2>/dev/null

use strict;
use warnings;
use DBI;
use Audio::TagLib;

my $mp3Root = "/music";
my $imgMissing = "/music/.covers/.missing.png";
my $dbConn  = dbGet();
my $fileCount = 0;

# artist   { indexArtist, name, genre, tags, note }
# album    { indexAlbum, indexArtist, title, year, cover, tags, note }
# song     { indexSong, indexArtist, indexAlbum, title, track, tags, note, file }

verifyDir($mp3Root);
# my @arr = `find /music | egrep "\.mp3"`; verifyArray(\@arr);
# sub verifyArray {
#   my $arrRef=shift; my @files=@{$arrRef};
#   foreach(@files) { $_ =~ s/\n//; verifyFile($_); }
# }
print "Processed $fileCount Files...\n";
verifySongs();
verifyAlbums();
verifyArtists();


sub verifyDir {
  my $root = shift;
  my @fils = @{dirFiles($root)};
  my @dirs = @{dirDirs($root)};
  $root .= '/';
  foreach(@fils) { verifyFile($root . $_); }
  foreach(@dirs) { verifyDir ($root . $_); }
}

sub verifyFile {
  my $filename = shift;
  my $id3 = id3Read($filename);
  my $artist = $id3->{'artist'};
  my $album  = $id3->{'album' };
  my $idxArtist=-2; if($artist ne "") { $idxArtist = dbArtistIdx($artist); }
  my $idxAlbum =-2; if(($idxArtist > -1) && ($album ne "")) { $idxAlbum  = dbAlbumIdx ($idxArtist, $album); }
  my $idxSong  = dbSongIdx($filename);
  $fileCount++;
  return if(($idxArtist>-1) && ($idxAlbum>-1) && ($idxSong>-1) && ($id3->{'coverFound'} eq 'yes'));
  print "\"$filename\"\n";
  print " * (missing ID3v2 artist)\n"             if($idxArtist == -2);
  print " * artist \"$artist\" not found in DB\n" if($idxArtist == -1);
  print " * (missing ID3v2 album)\n"              if($idxAlbum  == -2);
  print " * album \"$album\" not found in DB\n"   if($idxAlbum  == -1);
  print " * missing from song DB\n"               if($idxSong   == -1);
  print " * missing cover image\n"                if($id3->{'coverFound'} eq 'no');
  print " * cover image in unknown format\n"      if($id3->{'coverFound'} eq 'other');
}

sub verifySongs {
  my $q = dbQuery("SELECT indexSong, indexArtist, indexAlbum, title, track, file FROM song WHERE ((title='') OR (track=0)) ORDER BY indexArtist, indexAlbum, indexSong");
  $q->execute(); return if($q->rows == 0);
  for(my $i=0; $i<$q->rows; $i++) {
    my $aref = $q->fetchrow_arrayref();
    my $artistName = artistFromIndex($aref->[1]);
    my $albumName  = albumFromIndex($aref->[2]);
    print "SongIndex " . $aref->[0] . "\n";
    print "   file " . $aref->[5] . "\n";
    if($artistName eq "") { print " * artist (missing)\n"; } else { print "   artist \"$artistName\"\n";  }
    if($albumName  eq "") { print " * album (missing)\n";  } else { print "   album \"$albumName\"\n";    }
    if($aref->[3] eq "" ) { print " * title (missing)\n";  } else { print "   title \"$aref->[3]\"\n";    }
    if($aref->[4] == 0  ) { print " * track (missing)\n";  } else { print "   track $aref->[4]\n";        }
  }
}

sub verifyAlbums {
  my $q = dbQuery("SELECT indexAlbum, indexArtist, title, year, cover FROM album WHERE ((title='') OR (year=0) OR (cover='$imgMissing')) ORDER BY indexArtist, indexAlbum");
  $q->execute(); return if($q->rows == 0);
  for(my $i=0; $i<$q->rows; $i++) {
    my $aref = $q->fetchrow_arrayref();
    my $artistName = artistFromIndex($aref->[1]);
    print "AlbumIndex " . $aref->[0] . "\n";
    if($artistName eq "")         { print " * artist (missing)\n"; } else { print "   artist \"$artistName\"\n"; }
    if($aref->[2] eq "")          { print " * title (missing)\n";  } else { print "   title \"$aref->[2]\"\n";   }
    if($aref->[3] == 0)           { print " * year (missing)\n";   } else { print "   year $aref->[3]\n";        }
    if($aref->[4] eq $imgMissing) { print " * cover (missing)\n";  } else { print "   cover \"$aref->[4]\"\n";   }
  }
  $q->finish();
  return;
}

sub verifyArtists {
  my $q = dbQuery("SELECT indexArtist, name, genre FROM artist WHERE ((name='') OR (genre='')) ORDER BY indexArtist");
  $q->execute(); return if($q->rows == 0);
  for(my $i=0; $i<$q->rows; $i++) {
    my $aref = $q->fetchrow_arrayref();
    print "ArtistIndex " . $aref->[0] . "\n";
    if($aref->[1] eq "") { print " * name (missing)\n";  } else { print "   name \"" . $aref->[1] . "\"\n";  }
    if($aref->[2] eq "") { print " * genre (missing)\n"; } else { print "   genre \"" . $aref->[2] . "\"\n"; }
  }
  $q->finish();
}

sub artistFromIndex {
  my $q = dbQuery("SELECT name FROM artist WHERE (indexArtist = ?)");
  $q->execute(shift);
  my $result = ""; if($q->rows > 0) { $result = $q->fetchrow_arrayref()->[0]; }
  $q->finish(); return $result;
}

sub albumFromIndex {
  my $q = dbQuery("SELECT title FROM album WHERE (indexAlbum = ?)");
  $q->execute(shift);
  my $result = ""; if($q->rows > 0) { $result = $q->fetchrow_arrayref()->[0]; }
  $q->finish(); return $result;
}

sub dbArtistIdx {
  my $query = dbQuery("SELECT artist.indexArtist FROM artist WHERE (artist.name = ?)");
  $query->execute(shift);
  my $result = -1; if($query->rows > 0) { $result = $query->fetchrow_arrayref()->[0]; }
  $query->finish();
  return $result;
}

sub dbAlbumIdx {
  my $query = dbQuery("SELECT album.indexAlbum FROM album WHERE ((album.indexArtist = ?) AND (album.title = ?))");
  $query->execute(shift, shift);
  my $result = -1; if($query->rows > 0) { $result = $query->fetchrow_arrayref()->[0]; }
  $query->finish();
  return $result;
}

sub dbSongIdx {
  my $query = dbQuery("SELECT song.indexSong FROM song WHERE (song.file = ?)");
  $query->execute(shift);
  my $result = -1; if($query->rows > 0) { $result = $query->fetchrow_arrayref()->[0]; }
  $query->finish();
  return $result;
}

sub id3Read {
  my %id3 = ();
  my $filename = shift;
  my $handle = Audio::TagLib::MPEG::File->new($filename);
  my $tag = $handle->ID3v2Tag(1);
  $id3{'artist'} = $tag->artist()->toCString();
  $id3{'album' } = $tag->album ()->toCString();
  $id3{'title' } = $tag->title ()->toCString();
  $id3{'genre' } = $tag->genre ()->toCString();
  $id3{'track' } = $tag->track ();
  $id3{'year'  } = $tag->year  ();
  my $tagRef = \%id3;
  id3ReadCover($tagRef, $tag);
  return $tagRef;
}

sub id3ReadCover {
  my $id3=shift; my $tag=shift;
  my $idFrame = Audio::TagLib::ByteVector->new("APIC");
  my $idPNG   = Audio::TagLib::ByteVector->new("\x89\x50\x4E\x47");
  my $idJPEG  = Audio::TagLib::ByteVector->new("\xFF\xD8\xFF");
  my $frames = $tag->frameList($idFrame);  
  if($frames->size < 1) { $id3->{'coverFound'}="no"; return $id3; }
  tie my @frameArr, ref($frames), $frames;
  my $frameData = $frameArr[0]->render();
  my $offsetPNG  = $frameData->find($idPNG);
  my $offsetJPEG = $frameData->find($idJPEG);
  if(($offsetPNG == -1) && ($offsetJPEG == -1)) { $id3->{'coverFound'} = 'other'; return; }
  if(($offsetPNG  > -1) && ($offsetPNG < $offsetJPEG)) { $offsetJPEG = -1; }
  if(($offsetJPEG > -1) && ($offsetJPEG < $offsetPNG)) { $offsetPNG  = -1; }
  if($offsetPNG  == -1) { $id3->{'coverFound'} = 'yes'; $id3->{'coverExt'}='.jpg'; }
  if($offsetJPEG == -1) { $id3->{'coverFound'} = 'yes'; $id3->{'coverExt'}='.png'; }
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

sub dirDirs {
  my @arr; my $dir=shift; my $handle;
  opendir($handle, $dir);
  while(my $entry = readdir($handle)) {
    next unless (-d "$dir/$entry");
    next if (substr($entry,0,1) eq ".");
    push(@arr, "$entry");
  }
  closedir($handle);
  return \@arr;
}

sub dirFiles {
  my @arr; my $dir = shift; my $handle;
  opendir($handle, $dir);
  while(my $entry = readdir($handle)) {
    next unless (-f "$dir/$entry");
    next if (substr($entry,0,1) eq ".");
    push(@arr, "$entry");
  }
  closedir($handle);
  return \@arr;
}
