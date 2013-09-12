use strict;
use warnings;
use Audio::TagLib;

my $mp3Root = "/music";

my $fileArg = shift or die;
verifyFile($fileArg);

sub verifyFile {
  my $filename = shift;
  my $id3 = id3Read($filename);
  print "$filename\n";
  if($id3->{'artist'} eq "") { print "  Artist : (missing)\n"; } else { print "  Artist : \"" . $id3->{'artist'} . "\"\n"; }
  if($id3->{'album' } eq "") { print "  Album  : (missing)\n"; } else { print "  Album  : \"" . $id3->{'album' } . "\"\n"; }
  if($id3->{'genre' } eq "") { print "  Genre  : (missing)\n"; } else { print "  Genre  : \"" . $id3->{'genre' } . "\"\n"; }
  if($id3->{'year'  } ==  0) { print "  Year   : (missing)\n"; } else { print "  Year   :  "  . $id3->{'year'  } . " \n" ; }
  if($id3->{'track' } ==  0) { print "  Track  : (missing)\n"; } else { print "  Track  :  "  . $id3->{'track' } . " \n" ; }
  if($id3->{'coverFound'} eq 'no'   ) { print "  Cover  : (missing)\n";                       }
  if($id3->{'coverFound'} eq 'other') { print "  Cover  : (unrecognized format)\n";           }
  if($id3->{'coverFound'} eq 'yes'  ) { print "  Cover  : cover" . $id3->{'coverExt'} . "\n"; }
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
