#!/usr/local/bin/python3.3
# pymysql  : https://github.com/PyMySQL/PyMySQL
# mutagenx : https://github.com/LordSputnik/mutagen
# ==============================================================================
import os
import sys
import time
import uuid
import shutil
import mutagen as ID3
import pymysql as SQL

# ==============================================================================
PATH_ROOT   = "/Music"
PATH_COVERS = "/Music/.covers"
PATH_SERVED = "/music"

DATABASE_HOST  = 'localhost'
DATABASE_USER  = 'USER'
DATABASE_PASS  = 'PASS'
DATABASE_STORE = 'musicapp'

INDEX_ARTIST = 1
INDEX_ALBUM  = 0
INDEX_SONG   = 0

# ==============================================================================
class MP3():
    def __init__(self, path):
        global PATH_ROOT
        global PATH_SERVED
        fin = ID3.File(path)
        self.artist = str(fin.tags['TPE1'].text[0])
        self.album  = str(fin.tags['TALB'].text[0])
        self.title  = str(fin.tags['TIT2'].text[0])
        self.genre  = str(fin.tags['TCON'].text[0])               if ('TCON' in fin.tags) else ''
        self.track  = int(fin.tags['TRCK'].text[0].split('/')[0]) if ('TRCK' in fin.tags) else 0
        self.year   = int(fin.tags['TDRC'].text[0].year)          if ('TDRC' in fin.tags) else 1982
        self.uuid   = str(uuid.uuid4()).upper()
        self.path   = ''.join([PATH_SERVED, path[len(PATH_ROOT):]])
        self.cover  = None
        for tag in fin.tags:
            if (len(tag) > 5) and (tag[0:5] == 'APIC:'):
                self.cover = fin.tags[tag]
                filename = [self.uuid]
                if self.cover.desc.lower().endswith('.png'):
                    filename.append('.png')
                elif self.cover.desc.lower().endswith('.jpg'):
                    filename.append('.jpg')
                elif self.cover.data[0:4] == b'\x89\x50\x4E\x47':
                    filename.append('.png')
                elif self.cover.data[0:3] == b'\xFF\xD8\xFF':
                    filename.append('.jpg')
                self.cover.filename = ''.join(filename)
                break

    def write_cover(self, path):
        if self.cover is None: return
        path = os.path.join(path, self.cover.filename)
        fout = open(path, 'wb')
        fout.write(self.cover.data)
        fout.close()

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

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

def database_table_clear(db, table):
    cur = db.cursor()
    cur.execute('TRUNCATE TABLE {}'.format(table))
    cur.close()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

def database_clear_all(db):
    global PATH_COVERS
    directory_clear(PATH_COVERS)
    database_table_clear(db, 'artist')
    database_table_clear(db, 'album')
    database_table_clear(db, 'song')

# ==============================================================================
def directory_clear(path):
    for entry in os.listdir(path):
        if entry.lower() == 'missing.png': continue
        full = os.path.join(path, entry)
        if os.path.isfile(full):
            os.unlink(full)
        elif os.path.isdir(full):
            shutil.rmtree(full)

# ==============================================================================
def library_refresh(db, path):
    database_clear_all(db)
    database_execute(db, "INSERT INTO artist (indexArtist, name, genre) VALUES (0, 'Compilation', 'Compilation')")
    library_scan_dir(db, path)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

def library_scan_file(db, path):
    global INDEX_SONG
    mp3 = MP3(path)
    mp3.index_song = INDEX_SONG
    INDEX_SONG += 1
    if "/Compilations/" in path:
        mp3.index_artist = 0
    else:
      mp3.index_artist = entry_artist_id(db, mp3)
    mp3.index_album = entry_album_id(db, mp3)
    entry_insert_song(db, mp3)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

def library_scan_dir(db, path):
    write_path = path
    if len(write_path) > 80:
        write_path = write_path[0:80]
    if len(write_path) < 80:
        write_path = ''.join([write_path, ' '  * (80 - len(write_path))])
    sys.stdout.write('\b' * 80)
    sys.stdout.write(write_path)
    sys.stdout.flush()

    for entry in os.listdir(path):
        if entry[0] == '.': continue
        full = os.path.join(path, entry)
        if os.path.isfile(full):
            if entry.lower().endswith('.mp3'):
                library_scan_file(db, full)
        else:
            library_scan_dir(db, full)

# ==============================================================================
def entry_artist_id(db, mp3):
    global INDEX_ARTIST
    result = database_execute(db, "SELECT artist.indexArtist FROM artist WHERE (artist.name = ?)", [mp3.artist])
    if len(result) == 0:
        ret_index = INDEX_ARTIST
        database_execute(db, "INSERT INTO artist (indexArtist, name, genre) VALUES (?,?,?)", [ret_index, mp3.artist, mp3.genre])
        INDEX_ARTIST += 1
        return ret_index
    else:
        return result[0][0]

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

def entry_album_id(db, mp3):
    global INDEX_ALBUM
    global PATH_COVERS
    result = database_execute(db, "SELECT album.indexAlbum FROM album WHERE ((album.indexArtist = ?) AND (album.title = ?))",
                             [mp3.index_artist, mp3.album])
    if len(result) == 0:
        ret_index = INDEX_ALBUM
        if mp3.cover is not None:
            mp3.write_cover(PATH_COVERS)
        database_execute(db, "INSERT INTO album (indexAlbum, indexArtist, title, year, cover) VALUES (?,?,?,?,?)",
                         [ret_index, mp3.index_artist, mp3.album, mp3.year,
                          mp3.cover.filename if (mp3.cover is not None) else 'missing.png'])
        INDEX_ALBUM += 1
        return ret_index
    else:
        return result[0][0]

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

def entry_insert_song(db, mp3):
    database_execute(db, "INSERT INTO song (indexSong, indexArtist, indexAlbum, title, track, file) VALUES (?,?,?,?,?,?)",
                     [mp3.index_song, mp3.index_artist, mp3.index_album, mp3.title, mp3.track, mp3.path])


# ==============================================================================

sys.stdout.write(' ' * 80)
began = time.monotonic()
db = database_connect()
library_refresh(db, PATH_ROOT)
elapsed = int(time.monotonic() - began)
sys.stdout.write('\b' * 80)
print("Processed {} artists, {} albums, {} songs in {} seconds.".format(INDEX_ARTIST-1, INDEX_ALBUM, INDEX_SONG, elapsed))


# ==============================================================================
# ------------------------------------------------------------------------------
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
