use strict;
use warnings;
use DBI;
use IO::File;
use Data::GUID;
use Audio::TagLib;

my $mp3Root = "/music";
my $imgRoot = "/music/.covers";
my $appRoot = "/music";
my $dbConn  = dbGet();
my $newFiles = 0;
my $idxArtist=1; my $originArtist=1;
my $idxAlbum =0; my $originAlbum =0;
my $idxSong  =0; my $originSong  =0;

# artist   { indexArtist, name, genre, tags, note }
# album    { indexAlbum, indexArtist, title, year, cover, tags, note }
# song     { indexSong, indexArtist, indexAlbum, title, track, tags, note, file }
# list     { indexList, title, tags, note }
# listSong { indexList, indexSong, track, file } # file used for refresh/rebuild

updateDB();

sub updateDB {
  dbPrep();
  dbScan($mp3Root);
  print "Processed $newFiles new files.\n";
  return if($newFiles == 0);
  print "Inserted " . ($idxArtist - $originArtist) . " new artists, "
                    . ($idxAlbum  - $originAlbum ) . " new albums, "
                    . ($idxSong   - $originSong  ) . " new songs.\n";
}

sub dbPrep {
  my $q;
  $q = dbQuery("SELECT indexSong FROM song ORDER BY indexSong DESC"); $q->execute();
  if($q->rows > 0) { $idxSong = $q->fetchrow_arrayref()->[0]+1; $originSong=$idxSong; } $q->finish();
  $q = dbQuery("SELECT indexAlbum FROM album ORDER BY indexAlbum DESC"); $q->execute();
  if($q->rows > 0) { $idxAlbum = $q->fetchrow_arrayref()->[0]+1; $originAlbum=$idxAlbum; } $q->finish();
  $q = dbQuery("SELECT indexArtist FROM artist ORDER BY indexArtist DESC"); $q->execute();
  if($q->rows > 0) { $idxArtist = $q->fetchrow_arrayref()->[0]+1; $originArtist=$idxArtist; } $q->finish();
}

sub dbScan {
  my $root = shift;
  my @fils = @{dirFiles($root)};
  my @dirs = @{dirDirs($root)};
  $root .= '/';
  foreach(@fils) { dbScanFile($root . $_); }
  foreach(@dirs) { dbScan    ($root . $_); } 
}

sub dbScanFile {
  my $file = shift;
  my $index = dbSongFromFile($file);
  return if($index > -1);

  $newFiles++;
  my $id3 = id3Read($file);
  my $currArtist = 0;
  $currArtist = dbArtistId($id3) if(index($file, "/Compilations/") == -1);
  my $currAlbum  = dbAlbumId($id3, $currArtist);
  my $currSong   = $idxSong; $idxSong++;
  $file =~ s/^$mp3Root/$appRoot/;
  dbInsertSong($id3, $currSong, $currArtist, $currAlbum, $file);
}

sub dbSongFromFile {
  my $q = dbQuery("SELECT indexSong FROM song WHERE (file = ?)");
  $q->execute(shift);
  my $result = -1; if($q->rows > 0) { $result = $q->fetchrow_arrayref()->[0]; }
  $q->finish();
  return $result;
}

sub dbInsertSong {
  my $id3 = shift;
  my $q = dbQuery("INSERT INTO song (indexSong, indexArtist, indexAlbum, title, track, file) VALUES (?,?,?,?,?,?)");
  $q->execute(shift, shift, shift, $id3->{'title'}, $id3->{'track'}, shift);
  $q->finish();
}

sub dbArtistId {
  my $id3 = shift;
  my $q = dbQuery("SELECT artist.indexArtist FROM artist WHERE (artist.name = ?)");
  $q->execute($id3->{'artist'});
  if($q->rows == 0) {
    my $index=$idxArtist; $idxArtist++; $q->finish();
    $q = dbQuery("INSERT INTO artist (indexArtist, name, genre) VALUES (?,?,?)");
    $q->execute($index, $id3->{'artist'}, $id3->{'genre'}); $q->finish();
    return $index;
  } else {
    my $index = $q->fetchrow_arrayref()->[0];
    $q->finish();
    return $index;
  }  
}

sub dbAlbumId {
  my $id3 = shift; my $artId = shift;
  my $q = dbQuery("SELECT album.indexAlbum FROM album WHERE ((album.indexArtist = ?) AND (album.title = ?))");
  $q->execute($artId, $id3->{'album'});
  if($q->rows == 0) {
    my $index=$idxAlbum; $idxAlbum++; $q->finish();
    my $cover = id3StoreCover($id3); $cover =~ s/^$mp3Root/$appRoot/;
    $q = dbQuery("INSERT INTO album (indexAlbum, indexArtist, title, year, cover) VALUES (?,?,?,?,?)");
    $q->execute($index, $artId, $id3->{'album'}, $id3->{'year'}, $cover); $q->finish();
    return $index;
  } else {
    my $index = $q->fetchrow_arrayref()->[0];
    $q->finish();
    return $index;
  }
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
  if(($offsetPNG == -1) && ($offsetJPEG == -1)) { $id3->{'coverFound'} = 'no'; return; }
  if(($offsetPNG  > -1) && ($offsetPNG < $offsetJPEG)) { $offsetJPEG = -1; }
  if(($offsetJPEG > -1) && ($offsetJPEG < $offsetPNG)) { $offsetPNG  = -1; }
  if($offsetPNG  == -1) { $id3->{'coverFound'} = 'yes'; $id3->{'coverExt'}='.jpg'; $id3->{'coverData'}=$frameData->mid($offsetJPEG)->data(); }
  if($offsetJPEG == -1) { $id3->{'coverFound'} = 'yes'; $id3->{'coverExt'}='.png'; $id3->{'coverData'}=$frameData->mid($offsetPNG )->data(); }
}

sub id3StoreCover {
  my $id3=shift;
  if($id3->{'coverFound'} ne "yes") { return $imgRoot . "/.missing.png"; }
  my $uid = Data::GUID->new();
  my $path = $imgRoot . '/' . $uid->as_string() . $id3->{'coverExt'};
  my $file = IO::File->new($path, 'w');
  $file->print($id3->{'coverData'});
  $file->close();
  $id3->{'coverData'} = '';
  return $path;
}

sub dbQuery {
  my $id3=3;
  return $dbConn->prepare(shift);
}

sub dbClear {
  my $table = shift;
  my $q = dbQuery("TRUNCATE TABLE $table;");
  $q->execute();
  $q->finish();
}

sub dbGet {
  my $src  = "DBI:mysql:database=musicapp;host=localhost";
  my $conn = DBI->connect($src, "perldb", "------------"); # insert password
  return $conn;
}

sub dirDirs {
  my @arr; my $dir=shift; my $handle;
  opendir($handle, $dir);
  while(my $entry = readdir($handle)) {
    next unless (-d "$dir/$entry");
    next if (substr($entry,0,1) eq ".");
    push(@arr, $entry);
  }
  closedir($handle);
  return \@arr;
}

sub dirFiles {
  my @arr; my $dir = shift; my $handle;
  opendir($handle, $dir);
  while(my $entry = readdir($handle)) {
    next unless (-f "$dir/$entry");
    next if(substr($entry,0,1) eq ".");
    next if(! ($entry =~ /\.mp3$/));
    push(@arr, $entry);
  }
  closedir($handle);
  return \@arr;
}

sub dirClear {
  my $dir = shift;
  my @files = @{dirFiles($dir)};
  foreach(@files) { unlink $dir . "/" . $_; }
}
