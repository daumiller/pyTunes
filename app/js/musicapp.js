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
  content.append = function(el){ content.handle.appendChild(el); };
  content.setCategory = function(cat){
    content.clear();
    $(".catRoot li").removeClass("active");
    switch(cat)
    {
      case "genre":
      {
        $("#catRootGenre").addClass("active");
        $.getJSON("/app/pl/library.pl?qtype=genre", function(genres){
          genres.sort(); var html = "";
          for(var i=0; i<genres.length; i++)
          {
            var r = Math.floor(223.0+(Math.random()*32.0)).toString(16); if(r.length < 2) r = "0" + r;
            var g = Math.floor(223.0+(Math.random()*32.0)).toString(16); if(g.length < 2) g = "0" + g;
            var b = Math.floor(223.0+(Math.random()*32.0)).toString(16); if(b.length < 2) b = "0" + b;
            var color = "style=\"background-color:#" + r+g+b + ";\"";
            html += "<span class=\"contLargeText\" " + color + ">" + genres[i] + "</span>";
          }
          content.handle.innerHTML = html;
        });
      }
      break;

      case "artist":
      {
        $("#catRootArtist").addClass("active");
      }
      break;

      case "album":
      {
        $("#catRootAlbum").addClass("active");
      }
      break;

      case "song":
      {
        $("#catRootSong").addClass("active");
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
    player.source.setAttribute("src",src);
    player.handle.appendChild(player.source);
  };
  player.play   = function(){ player.handle.play();  };
  player.pause  = function(){ player.handle.pause(); };
  player.mute   = function(){ player.volStored=player.handle.volume; player.handle.volume=0.0; };
  player.unmute = function(){ player.handle.volume=player.volStored; };
  // https://developer.mozilla.org/en-US/docs/Web/Guide/HTML/Using_HTML5_audio_and_video
}

function initApp()
{
  content.setCategory("genre");
  //player.setSource("/music/Lights/Siberia/01 Siberia.mp3");
}
