$(function(){
  window.music = {};
  music.player    = new Player();
  music.content   = new Content();
  music.navigator = new Navigator();
  Navigator.setRoot();
  $("#btnPrev").click(Player.btnPrev_Clicked);
  $("#btnNext").click(Player.btnNext_Clicked);
});

//================================================================================================
//================================================================================================
//================================================================================================

function Navigator()
{
  this.el     = document.getElementById("divNavigation");
  this.trail  = document.getElementById("navTrail");
  this.search = document.getElementById("navSearch");
  this.state  = [];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Navigator.prototype.updateTrail = function()
{
  if(this.trail.childNodes.length == 0)
    $("<li class='navTrailItem'>Top</li>").appendTo(this.trail).click(Navigator.setRoot);
  while(this.trail.childNodes.length > 1) this.trail.removeChild(this.trail.childNodes[1]);
  
  for(var i=0; i<this.state.length; i++)
  {
    $("<li class='navTrailSeparator'>&nbsp;|&nbsp;</li>").appendTo(this.trail);
    if(this.state[i].category == "top")
      $("<li class='navTrailItem'>" + this.state[i].name + "</li>").appendTo(this.trail).click(Navigator.setTop);
    else if(this.state[i].category == "genre")
      $("<li class='navTrailItem'>" + this.state[i].name + "</li>").appendTo(this.trail).click(Navigator.setGenre);
    else if(this.state[i].category == "artist")
      $("<li class='navTrailItem'>" + this.state[i].name + "</li>").appendTo(this.trail).click(Navigator.setArtist)[0].obj = this.state[i].obj;
    else if(this.state[i].category == "album")
      $("<li class='navTrailItem'>" + this.state[i].name + "</li>").appendTo(this.trail).click(Navigator.setAlbum)[0].obj  = this.state[i].obj;
    else if(this.state[i].category == "search")
      $("<li class='navTrailItem'>" + this.state[i].name + "</li>").appendTo(this.trail).click(Navigator.setSearch)[0].obj = this.state[i].obj;
  }
};

//------------------------------------------------------------------------------------------------

Navigator.setRoot = function()
{
  var self = music.navigator;
  self.state.length = 0;
  self.updateTrail();
  
  music.content.loadGenres(Navigator.setTop, ["Genre", "Artist", "Album"]);
};

Navigator.setTop = function()
{
  var value = this.innerText;
  
  music.navigator.state.length = 0;
  music.navigator.state.push({name:value, category:"top"});
  music.navigator.updateTrail();
  
  music.content.clear();
  
  if(value == "Genre")
  {
    $.getJSON("/app/py/library.py?qtype=genre", function(genres){
      genres.sort();
      while(genres.length && genres[0].trim().length == 0) genres.splice(0,1); // skip blank genres
      music.content.loadGenres(Navigator.setGenre, genres);
    }).fail(function(){ alert("Error loading genres!"); });
    return;
  }
  
  if(value == "Artist")
  {
    $.getJSON("/app/py/library.py?qtype=artist", function(artists){
      artists.sort(artistSort);
      while(artists.length && artists[0].name.trim().length == 0) artists.splice(0,1); // skip blank artists
      music.content.loadArtists(Navigator.setArtist, artists);
    }).fail(function(){ alert("Error loading artists!"); });
    return;
  }
  
  if(value == "Album")
  {
    $.getJSON("/app/py/library.py?qtype=album", function(albums){
      albums.sort(albumSort);
      while(albums.length && albums[0].title.trim().length == 0) albums.splice(0,1); // skip blank albums
      music.content.loadAlbums(Navigator.setAlbum, albums);
    }).fail(function(){ alert("Error loading albums!"); });
    return;
  }
  
  if(value == "Search")
  {
  }
};

Navigator.setGenre = function()
{
  var value = this.innerText;
  music.navigator.state.length = 0;
  music.navigator.state.push({name:"Genre", category:"top"});
  music.navigator.state.push({name:value, category:"genre"});
  music.navigator.updateTrail();
  Navigator.albumSearch("genre=" + encodeURIComponent(value));
};

Navigator.setArtist = function()
{
  for(var i=0; i<music.navigator.state.length; i++)
  {
    if((music.navigator.state[i].category == "artist") && (music.navigator.state[i].obj.indexArtist == this.obj.indexArtist))
    {
      if(i < (music.navigator.state.length-1))
      {
        music.navigator.state.splice(i)
        music.navigator.updateTrail();
      }
      else
        return;
    }
  }
  
  music.navigator.state.push({name:this.innerText, obj:this.obj, category:"artist"});
  music.navigator.updateTrail();
  
  Navigator.albumSearch("artist=" + encodeURIComponent(this.obj.name));
};

Navigator.albumSearch = function(filter)
{
  var request = "/app/py/library.py?qtype=album";
  if(filter) request += '&' + filter;
  $.getJSON(request, function(albums){music.content.loadAlbums(Navigator.setAlbum, albums);});
};

Navigator.setAlbum = function()
{
  for(var i=0; i<music.navigator.state.length; i++)
  {
    if((music.navigator.state[i].category == "album") && (music.navigator.state[i].obj.indexAlbum == this.obj.indexAlbum))
    {
      if(i < (music.navigator.state.length-1))
      {
        music.navigator.state.splice(i)
        music.navigator.updateTrail();
      }
      else
        return;
    }
  }
  
  music.navigator.state.push({name:this.obj.title, obj:this.obj, category:"album"});
  music.navigator.updateTrail();
  
  $.getJSON("/app/py/library.py?qtype=song&indexAlbum=" + this.obj.indexAlbum,
    function(songs){ songs.sort(songSort); music.content.loadSongs(songs);
  }).fail(function(){ alert("Error loading album songs!"); });
};

Navigator.setSearch = function()
{
};

//================================================================================================
//================================================================================================
//================================================================================================

function Content()
{
  this.el = document.getElementById("divContent");
  this.urlList  = [];
  this.urlIndex = 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Content.prototype.clear = function()
  { while(this.el.childNodes.length > 0) this.el.removeChild(this.el.childNodes[0]); };

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Content.prototype.loadGenres = function(click, genres)
{
  this.urlList  = [];
  this.urlIndex = 0;
  this.clear();
  
  for(var i=0; i<genres.length; i++)
  {
    var item = document.createElement("SPAN");
    item.className = "contentItem contentText";
    item.style.backgroundColor = rndColor();
    item.innerText = genres[i];
    item.onclick   = click;
    item.style.fontSize = fitTextWidth(item.innerText, 128-12);
    this.el.appendChild(item);
  }
};

Content.prototype.loadArtists = function(click, artists)
{
  this.urlList  = [];
  this.urlIndex = 0;
  this.clear();
  
  for(var i=0; i<artists.length; i++)
  {
    if(artists[i].name == "06") continue; //hack...
    var item = document.createElement("SPAN");
    item.className = "contentItem contentText";
    item.style.backgroundColor = rndColor();
    item.innerText = artists[i].name;
    item.obj       = artists[i];
    item.onclick   = click;
    item.style.fontSize = fitTextWidth(item.innerText, 128-12);
    this.el.appendChild(item);
  }
};

Content.prototype.loadAlbums = function(click, albums)
{
  this.urlList  = [];
  this.urlIndex = 0;
  this.clear();
  
  for(var i=0; i<albums.length; i++)
  {
    var item = document.createElement("SPAN");
    item.title     = albums[i].artist + " : " + albums[i].title;
    item.className = "contentItem contentImage";
    item.style.backgroundImage = "url(cover/" + albums[i].cover + ')';
    item.obj       = albums[i];
    item.onclick   = click;
    this.el.appendChild(item);
  }
};

Content.prototype.loadSongs = function(songs)
{
  this.urlList  = [];
  this.urlIndex = -1;
  this.clear();
  this.songs = songs;
  
  var table = $("<table class=\"songList\"><tbody><tr class=\"songHead\">" +
                   "<th class=\"listSortable\"> Genre  </th>" +
                   "<th class=\"listSortable\"> Artist </th>" +
                   "<th class=\"listSortable\"> Year   </th>" +
                   "<th class=\"listSortable\"> Album  </th>" +
                   "<th class=\"listSortable\"> Track  </th>" +
                   "<th class=\"listSortable\"> Title  </th>" +
                 "</tr></tbody></table>").appendTo(this.el);
  var tbody = $("tbody", table)[0];
  for(var i=0; i<songs.length; i++)
  {
    this.urlList.push(songs[i].file);
    var row = document.createElement("tr");
    var tdGenre =$("<td></td>").appendTo(row)[0]; tdGenre .innerText = songs[i].genre;
    var tdArtist=$("<td></td>").appendTo(row)[0]; tdArtist.innerText = songs[i].artist;
    var tdYear  =$("<td></td>").appendTo(row)[0]; tdYear  .innerText = songs[i].year;
    var tdAlbum =$("<td></td>").appendTo(row)[0]; tdAlbum .innerText = songs[i].album;
    var tdTrack =$("<td></td>").appendTo(row)[0]; tdTrack .innerText = songs[i].track;
    var tdTitle =$("<td></td>").appendTo(row)[0]; tdTitle .innerText = songs[i].title;
    row.url       = songs[i].file;
    row.className = "songItem";
    row.onclick   = Content.songRowSelected;
    tbody.appendChild(row);
  }
};


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Content.prototype.songPrev = function()
{
  if(this.urlList.length == 0) return;
  if(this.urlIndex == 0)
    this.urlIndex = (this.urlList.length - 1);
  else
    this.urlIndex--;
  music.player.setSong(this.urlList[this.urlIndex]);
};

Content.prototype.songNext = function()
{
  if(music.player.repeatSong)
  {
    music.player.setSong(musig.player.getSong());
    return;
  }
  if(this.urlList.length == 0) return;
  if(this.urlIndex == (this.urlList.length - 1))
  {
    if(!music.player.repeatList) return;
    this.urlIndex = 0;
  }
  else
    this.urlIndex++;
  music.player.setSong(this.urlList[this.urlIndex]);
};

//------------------------------------------------------------------------------------------------

Content.songRowSelected = function()
{
  music.player.setSong(this.url);
};

//================================================================================================
//================================================================================================
//================================================================================================

function Player()
{
  this.el         = document.getElementById("divPlayer");
  this.controller = document.getElementById("playerControl");
  this.source     = document.getElementById("playerSource");
  
  this.repeatSong = this.repeatList = false;
  this.muted = false;
  this._storedVolume = 100.0;
  
  $("#btnRepeatSong").click(Player.btnRepeatSong_Clicked);
  $("#btnRepeatList").click(Player.btnRepeatList_Clicked);
  $("#btnPrev"      ).click(Player.btnPrev_Clicked);
  $("#btnNext"      ).click(Player.btnNext_Clicked);
  
  this.controller.addEventListener("ended", Player.songCompleted);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Player.prototype.play  = function(){ this.controller.play (); return this; };
Player.prototype.pause = function(){ this.controller.pause(); return this; };
Player.prototype.mute  = function(m)
{
  if(typeof(m) == "undefined") m = !this.muted;
  this.muted = m;
  if(this.muted)
  {
    this._storedVolume = this.controller.volume;
    this.controller.volume = 0.0;
  }
  else
    this.controller.volumd = this._storedVolume;
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Player.prototype.getSong = function() { return this.source.getAttribute("src"); };
Player.prototype.setSong = function(url)
{
  $(".songItemActive").removeClass("songItemActive");
  if(music.content.songs)
  {
    var rows = $("tr", music.content.el);
    for(var i=1; i<rows.length; i++)
      if(rows[i].url == url)
        { music.content.urlIndex=i-1; $(rows[i]).addClass("songItemActive"); break; }
  }
  
  this.source.setAttribute("src", url);
  this.controller.load();
  this.controller.play();
  return this;
};

//------------------------------------------------------------------------------------------------

Player.btnRepeatSong_Clicked = function()
{
  rs = !music.player.repeatSong;
  music.player.repeatSong = rs;
  $(this).removeClass(rs ? "btnRepeatSongOff" : "btnRepeatSongOn" )
            .addClass(rs ? "btnRepeatSongOn"  : "btnRepeatSongOff");
};

Player.btnRepeatList_Clicked = function()
{
  rl = !music.player.repeatList;
  music.player.repeatList = rl;
  $(this).removeClass(rl ? "btnRepeatListOff" : "btnRepeatListOn" )
            .addClass(rl ? "btnRepeatListOn"  : "btnRepeatListOff");
};

Player.btnPrev_Clicked = function() { music.content.songPrev(); };
Player.btnNext_Clicked = function() { music.content.songNext(); };
Player.songCompleted   = function() { music.content.songNext(); };

//================================================================================================
//================================================================================================
//================================================================================================

String.prototype.trim=function(){return this.replace(/^\s+|\s+$/g, '');};

//------------------------------------------------------------------------------------------------

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

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// songSort sorts by various, re-arrangable, data types
function songSort(a,b)
{
  for(var i=0; i<songSort.stack.length; i++)
  {
    var va = a[songSort.stack[i]];
    var vb = b[songSort.stack[i]];
    if((songSort.stack[i] == "year") || (songSort.stack[i] == "track"))
    {
      va |= 0;
      vb |= 0;
    }
    if(va != vb) return (va > vb) ? 1 : -1;
  }
  return 1;
}
songSort.stack = ["artist", "year", "album", "track", "title"]; // default priorty
songSort.priority = function(type)
{
  var index = -1;
  for(var i=0; i<songSort.stack.length; i++)
    if(songSort.stack[i] == type) { index = i; break; }
  if(index == -1) return; //not something we sort by...
  songSort.stack.splice(index, 1);
  songSort.stack.splice(0, 0, type);
};

//------------------------------------------------------------------------------------------------

function fitTextWidth(text, width)
{
  var fitter = $("#contentFitter");
  fitter[0].innerText = text;
  i = 16;
  fitter[0].style.fontSize = "16px";
  while(fitter.width() > width)
  {
    i -= 1;
    fitter[0].style.fontSize = i + "px";
  }
  return i + "px";
}

//------------------------------------------------------------------------------------------------

function rndColor()
{
  var r = Math.floor(223.0+(Math.random()*32.0)).toString(16); if(r.length < 2) r = "0" + r;
  var g = Math.floor(223.0+(Math.random()*32.0)).toString(16); if(g.length < 2) g = "0" + g;
  var b = Math.floor(223.0+(Math.random()*32.0)).toString(16); if(b.length < 2) b = "0" + b;
  return '#' + r + g + b;
}

//================================================================================================
//------------------------------------------------------------------------------------------------
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
