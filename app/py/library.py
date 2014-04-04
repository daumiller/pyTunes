import json
import pcgi as cgi
import pymysql as sql

# ==============================================================================
def request():
    if not cgi.has_param('qtype'):
        cgi.response('')
        return
    qtype = cgi.get_param('qtype')
    if   qtype == 'total' : request_total()
    elif qtype == 'genre' : request_genre()
    elif qtype == 'artist': request_artist()
    elif qtype == 'album' : request_album()
    elif qtype == 'song'  : request_song()
    else: cgi.response_404()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

def request_total():
    songs   = db_query('SELECT COUNT(*) FROM song')[0][0]
    albums  = db_query('SELECT COUNT(*) FROM album')[0][0]
    artists = db_query('SELECT COUNT(*) FROM artist')[0][0]
    cgi.response_object(songs=songs, albums=albums, artists=artists)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

def request_genre():
    genres = db_query('SELECT DISTINCT genre FROM artist')
    genres = [x[0] for x in genres]
    cgi.response(json.dumps(genres))

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

def request_artist():
    query = 'SELECT indexArtist, name, genre, tags, note FROM artist'
    where = []
    params = []

    if cgi.has_param('genre'):
        where.append('(genre = ?)')
        params.append(cgi.get_param('genre'))
    if cgi.has_param('tags'):
        where.append('(tags LIKE ?)')
        params.append(''.join(['%', cgi.get_param('tags'), '%']))
    if cgi.has_param('note'):
        where.append('(note LIKE ?)')
        params.append(''.join(['%', cgi.get_param('note'), '%']))

    if len(where):
        where = ' AND '.join(where)
        query = ' WHERE '.join([query, where])
    if not len(params):
        params = None

    arr = []
    for item in db_query(query, params=params):
        arr.append({'indexArtist' : item[0],
                    'name' : item[1],
                    'genre': item[2],
                    'tags' : item[3],
                    'note' : item[4]})
    cgi.response(json.dumps(arr))

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

def request_album():
    query = 'SELECT album.indexAlbum, artist.name, album.title, album.year, album.cover, album.tags, album.note, artist.genre FROM album, artist'
    where = ['(artist.indexArtist = album.indexArtist)']
    params = []

    if cgi.has_param('artist'):
        where.append('(artist.name = ?)')
        params.append(cgi.get_param('artist'))
    if cgi.has_param('genre'):
        where.append('(artist.genre = ?)')
        params.append(cgi.get_param('genre'))
    if cgi.has_param('year'):
        where.append('(album.year = ?)')
        params.append(cgi.get_param('year'))
    if cgi.has_param('tags'):
        where.append('(album.tags LIKE ?)')
        params.append(''.join(['%', cgi.get_param('tags'), '%']))
    if cgi.has_param('album.note'):
        where.append('(note LIKE ?)')
        params.append(''.join(['%', cgi.get_param('note'), '%']))

    if len(where):
        where = ' AND '.join(where)
        query = ' WHERE '.join([query, where])
    if not len(params):
        params = None

    arr = []
    for item in db_query(query, params=params):
        arr.append({'indexAlbum' : item[0],
                    'artist' : item[1],
                    'title'  : item[2],
                    'year'   : item[3],
                    'cover'  : item[4],
                    'tags'   : item[5],
                    'note'   : item[6],
                    'genre'  : item[7]})
    cgi.response(json.dumps(arr))

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

def request_song():
    query = 'SELECT song.indexSong, artist.name, album.title, song.title, song.track, song.tags, song.note, album.year, artist.genre, song.file FROM song, album, artist'
    where = ['(song.indexAlbum = album.indexAlbum)', '(song.indexArtist = artist.indexArtist)']
    params = []

    if cgi.has_param('indexAlbum'):
        where.append('(song.indexAlbum = ?)')
        params.append(cgi.get_param('indexAlbum'))
    if cgi.has_param('index'):
        where.append('(song.indexSong = ?)')
        params.append(cgi.get_param('index'))
    if cgi.has_param('artist'):
        where.append('(artist.name = ?)')
        params.append(cgi.get_param('artist'))
    if cgi.has_param('album'):
        where.append('(album.title = ?)')
        params.append(cgi.get_param('album'))
    if cgi.has_param('genre'):
        where.append('(artist.genre = ?)')
        params.append(cgi.get_param('genre'))
    if cgi.has_param('year'):
        where.append('(album.year = ?)')
        params.append(cgi.get_param('year'))
    if cgi.has_param('tags'):
        where.append('(songs.tags LIKE ?)')
        params.append(''.join(['%', cgi.get_param('tags'), '%']))
    if cgi.has_param('note'):
        where.append('(songs.note LIKE ?)')
        params.append(''.join(['%', cgi.get_param('note'), '%']))
    if cgi.has_param('title'):
        where.append('(song.title LIKE ?)')
        params.append(''.join(['%', cgi.get_param('title'), '%']))

    if len(where):
        where = ' AND '.join(where)
        query = ' WHERE '.join([query, where])
    if not len(params):
        params = None

    arr = []
    for item in db_query(query, params=params):
        arr.append({'indexSong' : item[0],
                    'artist' : item[1],
                    'album'  : item[2],
                    'title'  : item[3],
                    'track'  : item[4],
                    'tags'   : item[5],
                    'note'   : item[6],
                    'year'   : item[7],
                    'genre'  : item[8],
                    'file'   : item[9]})
    cgi.response(json.dumps(arr))

# ==============================================================================
_DB = None
def db_get():
    global _DB
    if _DB is None:
        _DB = sql.connect(host='localhost', user='USER', passwd='PASS', db='musicapp')
        db_query('SET NAMES utf8')
    return _DB

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

def db_close():
    global _DB
    if _DB is not None:
        _DB.close()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

def db_query(query, params=None):
    db = db_get()
    if params is not None:
        params = [db.escape(x) for x in params]
        query = query.replace('?','{}').format(*params)
    cur = db.cursor()
    cur.execute(query)
    result = cur.fetchall() or []
    cur.close()
    return result

# ==============================================================================
cgi.init()
request()
db_close()

# ==============================================================================
# ------------------------------------------------------------------------------
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
