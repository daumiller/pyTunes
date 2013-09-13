String.prototype.trim=function(){return this.replace(/^\s+|\s+$/g, '');};
var player  = {};
var content = {};

$(function(){
  initCategories();
  initContent();
  initPlayer();
  initApp();
});

function initCategories()
{
  document.getElementById("catRootGenre" ).onclick = function(){content.setCategory("genre" );};
  document.getElementById("catRootArtist").onclick = function(){content.setCategory("artist");};
  document.getElementById("catRootAlbum" ).onclick = function(){content.setCategory("album" );};
  document.getElementById("catRootSong"  ).onclick = function(){content.setCategory("song"  );};
}

function initContent()
{
  content.handle = $("#divContent")[0];
  content.clear = function(){
    while(content.handle.childNodes.length > 0)
      content.handle.removeChild(content.handle.childNodes[0]);
  };
  content.append = function(el){
    if(el.length)
      for(var i=0; i<el.length; i++) content.handle.appendChild(el[i]);
    else
      content.handle.appendChild(el);
  };
  content.setCategory = function(cat){
    content.clear();
    $(".catRoot li").removeClass("active");
    switch(cat)
    {
      case "genre":
      {
        $("#catRootGenre").addClass("active");
        $.getJSON("/app/pl/library.pl?qtype=genre", function(genres){
          genres.sort(); var begin = (genres[0].trim().length == 0) ? 1 : 0;
          for(var i=begin; i<genres.length; i++)
          {
            var genre = document.createElement("SPAN");
            genre.innerText = genres[i];
            genre.className = "contLarge contText";
            var r = Math.floor(223.0+(Math.random()*32.0)).toString(16); if(r.length < 2) r = "0" + r;
            var g = Math.floor(223.0+(Math.random()*32.0)).toString(16); if(g.length < 2) g = "0" + g;
            var b = Math.floor(223.0+(Math.random()*32.0)).toString(16); if(b.length < 2) b = "0" + b;
            genre.style.backgroundColor = "#" + r + g + b;
            genre.rawGenre = genres[i];
            genre.onclick = genreSelected;
            content.append(genre);
          }
        });
      }
      break;

      case "artist":
      {
        $("#catRootArtist").addClass("active");
        $.getJSON("/app/pl/library.pl?qtype=artist", function(artists){
          artists.sort(artistSort); var begin = (artists[0].name.trim().length == 0) ? 1 : 0;
          for(var i=begin; i<artists.length; i++)
          {
            var artist = document.createElement("SPAN");
            artist.innerText = artists[i].name;
            artist.className = "contLarge contText";
            var r = Math.floor(223.0+(Math.random()*32.0)).toString(16); if(r.length < 2) r = "0" + r;
            var g = Math.floor(223.0+(Math.random()*32.0)).toString(16); if(g.length < 2) g = "0" + g;
            var b = Math.floor(223.0+(Math.random()*32.0)).toString(16); if(b.length < 2) b = "0" + b;
            artist.style.backgroundColor = "#" + r + g + b;
            artist.rawArtist = artists[i].name;
            artist.onclick = artistSelected;
            content.append(artist);
          }
        });
      }
      break;

      case "album":
      {
        $("#catRootAlbum").addClass("active");
        albumLoad();
      }
      break;

      case "song":
      {
        $("#catRootSong").addClass("active");
        songLoad();
      }
      break;
    }
  };
}

function initPlayer()
{
  player.handle = $("#playerControl")[0];
  player.source = $("#playerSource" )[0];
  player.setSource = function(src) {
    player.source.setAttribute("src", src);
    player.handle.load();
  };
  player.play   = function(){ player.handle.play();  };
  player.pause  = function(){ player.handle.pause(); };
  player.mute   = function(){ player.volStored=player.handle.volume; player.handle.volume=0.0; };
  player.unmute = function(){ player.handle.volume=player.volStored; };
  // https://developer.mozilla.org/en-US/docs/Web/Guide/HTML/Using_HTML5_audio_and_video
  player.handle.addEventListener("ended", songFinished);
}

function initApp()
{
  content.setCategory("genre");
}

function genreSelected () { albumLoad("genre="      + encodeURIComponent(this.rawGenre ));  }
function artistSelected() { albumLoad("artist="     + encodeURIComponent(this.rawArtist));  }
function albumSelected () { songLoad ("indexAlbum=" + encodeURIComponent(this.rawAlbum ));  }
function songSelected()
{
  $(".contListActive").removeClass("contListActive");
  $(this).closest("tr").addClass("contListActive");
  player.setSource(this.file); player.play();
}
function songFinished()
{
  var wasSelected = $(".contListActive"); if(wasSelected.length == 0) return;
  var newActive = wasSelected.removeClass("contListActive").next();
  if(newActive.length == 0) return;
  newActive.addClass("contListActive");
  columns = $("td", newActive);
  songSelected.call($("span",columns[columns.length-1])[0]);
}

function albumLoad(filter)
{
  var request = "/app/pl/library.pl?qtype=album";
  if(filter) request += '&' + filter;
  $.getJSON(request, albumPopulate);
}
function albumPopulate(albums)
{
  // [ {indexAlbum, cover, artist, title, note, tags, year, genre}, ... ]
  content.clear(); albums.sort(albumSort);
  for(var i=0; i<albums.length; i++)
  {
    var album = document.createElement("SPAN");
    album.className = "contLarge contIcon";
    album.style.borderRadius = "0px";
    album.style.backgroundImage = "url(" + albums[i].cover + ')';
    album.rawAlbum = albums[i].indexAlbum;
    album.onclick = albumSelected;
    content.append(album);
  }
}
function albumSort(a,b)
{
  if(a.artist != b.artist) return (a.artist > b.artist) ? 1 : -1;
  if(a.year   != b.year  ) return (a.year   > b.year  ) ? 1 : -1;
  if(a.title  != b.title ) return (a.title  > b.title ) ? 1 : -1;
  return 1;
}

function artistSort(a,b)
{
  return (a.name > b.name) ? 1 : -1;
}

function songLoad(filter)
{
  var request = "/app/pl/library.pl?qtype=song";
  if(filter) request += '&' + filter;
  $.getJSON(request, songPopulate);
}
function songPopulate(songs)
{
  // [ {indexSong, artist, album, title, track, tags, note, year, genre, file}, ... ]
  content.clear(); songs.sort(songSort);
  var table = $("<table class=\"contList\"><tbody><tr class=\"contHead\">" +
                   "<th class=\"listSortable\"> Genre  </th>" +
                   "<th class=\"listSortable\"> Artist </th>" +
                   "<th class=\"listSortable\"> Year   </th>" +
                   "<th class=\"listSortable\"> Album  </th>" +
                   "<th class=\"listSortable\"> Track  </th>" +
                   "<th class=\"listSortable\"> Title  </th>" +
                   "<th></th>" +
                 "</tr></tbody></table>").appendTo(content.handle);;
  $(".listSortable", table).click(songResort);
  var tbody = $("tbody", table)[0];
  for(var i=0; i<songs.length; i++)
  {
    var row = document.createElement("tr");
    var tdGenre =$("<td></td>").appendTo(row)[0]; tdGenre .innerText = songs[i].genre;
    var tdArtist=$("<td></td>").appendTo(row)[0]; tdArtist.innerText = songs[i].artist;
    var tdYear  =$("<td></td>").appendTo(row)[0]; tdYear  .innerText = songs[i].year;
    var tdAlbum =$("<td></td>").appendTo(row)[0]; tdAlbum .innerText = songs[i].album;
    var tdTrack =$("<td></td>").appendTo(row)[0]; tdTrack .innerText = songs[i].track;
    var tdTitle =$("<td></td>").appendTo(row)[0]; tdTitle .innerText = songs[i].title;
    var tdPlay  =$("<td></td>").appendTo(row)[0];
    var tdPlayBtn = $("<span class=\"contPlayBtn\"></span>").appendTo(tdPlay)[0];
    tdPlayBtn.file = songs[i].file;
    tdPlayBtn.onclick = songSelected;
    tbody.appendChild(row);
  }
}
function songSort(a,b)
{
  a.year  = a.year |0;
  a.track = a.track|0;
  if(a.artist != b.artist) return (a.artist > b.artist) ? 1 : -1;
  if(a.year   != b.year  ) return (a.year   > b.year  ) ? 1 : -1;
  if(a.album  != b.album ) return (a.album  > b.album ) ? 1 : -1;
  if(a.track  != b.track ) return (a.track  > b.track ) ? 1 : -1;
  if(a.title  != b.title ) return (a.title  > b.title ) ? 1 : -1;
  return 1;
}
function songResort(col)
{
  alert(this.innerText.trim());
}
