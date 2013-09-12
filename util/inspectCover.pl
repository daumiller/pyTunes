use strict;
use warnings;
use Audio::TagLib;

my $fileArg = shift or die;
verifyFile($fileArg);

sub verifyFile {
  my $filename = shift;
  my $id3 = id3Read($filename);
  print "$filename\n";
  if($id3->{'coverFound'} eq 'no' ) { print "  cover missing.\n"; return; }
  if($id3->{'coverFound'} eq 'yes') { print "  cover recognized (" . $id3->{'coverExt'} . ")\n"; return; }
  for(my $i= 0; $i<32; $i++) { printf "%02x ",ord($id3->{'coverData'}->at($i)); } print "\n";
  for(my $i=32; $i<64; $i++) { printf "%02x ",ord($id3->{'coverData'}->at($i)); } print "\n";
}

sub id3Read {
  my %id3 = ();
  my $filename = shift;
  my $handle = Audio::TagLib::MPEG::File->new($filename);
  my $tag = $handle->ID3v2Tag(1);
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
  if(($offsetPNG == -1) && ($offsetJPEG == -1)) { $id3->{'coverFound'}='other'; $id3->{'coverData'}=$frameData->mid(0,64); return; }
  if(($offsetPNG  > -1) && ($offsetPNG < $offsetJPEG)) { $offsetJPEG = -1; }
  if(($offsetJPEG > -1) && ($offsetJPEG < $offsetPNG)) { $offsetPNG  = -1; }
  if($offsetPNG  == -1) { $id3->{'coverFound'} = 'yes'; $id3->{'coverExt'}='.jpg'; }
  if($offsetJPEG == -1) { $id3->{'coverFound'} = 'yes'; $id3->{'coverExt'}='.png'; }
}
