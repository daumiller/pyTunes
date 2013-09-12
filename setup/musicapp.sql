CREATE DATABASE musicapp;
CREATE TABLE artist (indexArtist INT PRIMARY KEY, name VARCHAR(256), genre VARCHAR(256), tags VARCHAR(1024), note VARCHAR(1024));
CREATE TABLE album (indexAlbum INT PRIMARY KEY, indexArtist INT, title VARCHAR(256), year INT, cover VARCHAR(512), tags VARCHAR(1024), note VARCHAR(1024));
CREATE TABLE song (indexSong INT PRIMARY KEY, indexArtist INT, indexAlbum INT, title VARCHAR(256), track INT, tags VARCHAR(1024), note VARCHAR(1024), file VARCHAR(512));
CREATE TABLE list (indexList INT PRIMARY KEY, title VARCHAR(256), tags VARCHAR(1024), note VARCHAR(1024));
CREATE TABLE listSong (indexList INT, indexSong INT, track INT, file VARCHAR(512));
