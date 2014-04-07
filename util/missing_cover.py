#!/usr/local/bin/python3.3
# ==============================================================================
import pymysql as SQL

# ==============================================================================
DATABASE_HOST  = 'localhost'
DATABASE_USER  = 'USER'
DATABASE_PASS  = 'PASS'
DATABASE_STORE = 'musicapp'

# ==============================================================================
# artist   { indexArtist, name, genre, tags, note }
# album    { indexAlbum, indexArtist, title, year, cover, tags, note }
# song     { indexSong, indexArtist, indexAlbum, title, track, tags, note, file }
# list     { indexList, title, tags, note }
# listSong { indexList, indexSong, track, file } # file used for refresh/rebuild

def database_connect():
    global DATABASE_HOST
    global DATABASE_USER
    global DATABASE_PASS
    global DATABASE_STORE
    db = SQL.connect(host=DATABASE_HOST, user=DATABASE_USER, passwd=DATABASE_PASS, db=DATABASE_STORE)
    database_execute(db, 'SET NAMES utf8')
    db.encoding = 'UTF-8'
    return db

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

def database_execute(db, query, args=None):
    cur = db.cursor()
    if args is not None:
        args = [db.escape(x) for x in args]
        query = query.replace('?','{}').format(*args)
    cur.execute(query)
    result = cur.fetchall() or []
    cur.close()
    return result

# ==============================================================================

db = database_connect()
missing = database_execute(db, """
    SELECT artist.name, album.title
    FROM album, artist
    WHERE (album.cover like 'missing.png') AND (artist.indexArtist = album.indexArtist)
    ORDER BY artist.name, album.year
""")

namelen = 0
for entry in missing:
    elen = len(entry[0])
    if elen > namelen:
        namelen = elen

for entry in missing:
    elen = len(entry[0])
    print("{}{} :: {}".format(entry[0], ' ' * (namelen - elen), entry[1]))

# ==============================================================================
# ------------------------------------------------------------------------------
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
