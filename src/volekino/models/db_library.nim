import db_sqlite
import sqlite3
import os
import strutils
type LibraryDb* = distinct DbConn
import util
import ../../common/library_types
export library_types.LibraryEntry
import ../globals
import ../ffprobe
import ../uid
import json

const SQL_STATEMENTS = statementsFrom("./statements/library.sql")

#[
proc hasEntry*(library: LibraryDb, path: string): bool =
  const statement = slurp("./statements/library/hasentry.sql")
  let db = DbConn(library)
  let val = db.getValue(sql statement, path)
  val == "1"

]#

proc hasEntry*(library: LibraryDb, uid: string): bool =
  let db = DbConn(library)
  let val = db.getValue(sql SQL_STATEMENTS["hasuid"], uid)
  val == "1"

proc createTable*(db: DbConn): LibraryDb =
  db.exec(sql SQL_STATEMENTS["create"])
  return LibraryDb(db)


proc addEntry*(library: LibraryDb, path, uid, videoEncoding, audioEncoding: string, duration: int, audioTracks: string, resolution: string, aspectRatio: string) =
  let db = DbConn(library)
  db.exec(sql SQL_STATEMENTS["add"], path, uid, videoEncoding, audioEncoding, duration, audioTracks, resolution, aspectRatio)
  

proc loadEntry*(mediaSource: string): LibraryEntry =
  if not libraryDirCreated:
    #createDir libraryDir
    libraryDirCreated = true

  result = LibraryEntry(uid: genUid())
  result.path = mediaSource[mediaDir.len + 1..^1]
  let probe = ffprobe(mediaSource)
  result.duration = probe.duration
  result.videoEncoding = probe.videoStreamType
  result.audioEncoding = probe.audioStreamType
  for track in probe.audioTracks:
    result.audioTracks.add AudioTrackIdentifier(title: track.title, lang: track.lang, index: track.index)

  let videoTrack = probe.videoTrack

  result.resolution = videoTrack.resolution
  result.aspectRatio = videoTrack.aspectRatio

  createSymLink(mediaSource, libraryDir / result.uid)


proc addMediaSource*(library: LibraryDb, mediaSource: string): string =
  let loaded = loadEntry(mediaSource)
  let probe = ffprobe(mediaSource)
  result = loaded.uid
  library.addEntry(loaded.path, result, loaded.videoEncoding, loaded.audioEncoding, loaded.duration, $(% loaded.audioTracks), loaded.resolution, loaded.aspectRatio)


proc entryFromRow(row: Row): LibraryEntry =
  LibraryEntry(
    uid: row[0],
    path: row[1],
    videoEncoding: row[2],
    audioEncoding: row[3],
    duration: parseInt row[4],
    audioTracks: parseJson(row[5]).to(seq[AudioTrackIdentifier]),
    resolution: row[6],
    aspectRatio: row[7]
  )
  


proc getEntry*(library: LibraryDb, uid: string): LibraryEntry =
  let db = DbConn(library)
  let row = db.getRow(sql SQL_STATEMENTS["get-entry"], uid)

  entryFromRow row

proc getEntryUid*(library: LibraryDb, mediaSource: string): string =
  let db = DbConn(library)
  db.getValue(sql SQL_STATEMENTS["get-entry-uid"], mediaSource[mediaDir.len + 1..^1])
  
 
proc removeEntry*(library: LibraryDb, uid: string) =
  let db = DbConn(library)
  removeFile(libraryDir / uid)
  try:
    let path = library.getEntry(uid).path
    removeFile(mediaDir / path)
  except: discard
  db.exec(sql SQL_STATEMENTS["remove"], uid)


proc removeOrphanEntries*(library: LibraryDb) =
  for (kind, path) in walkDir(libraryDir):
    if kind == pcLinkToFile and not fileExists(expandSymlink(path)):
      library.removeEntry(path.splitFile()[1])
  

proc getAll*(library: LibraryDb): seq[LibraryEntry] =
  let db = DbConn(library)
  for row in db.rows(sql SQL_STATEMENTS["getall"], ""):
    result.add entryFromRow(row)


