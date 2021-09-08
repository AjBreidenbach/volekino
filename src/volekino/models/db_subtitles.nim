import util
import db_sqlite
import ../../common/library_types
import ../ffprobe
import os
import ../uid
import ../globals
#import db_library
import strutils
import osproc
import strformat
import sequtils


const SQL_STATEMENTS = statementsFrom("./statements/subtitles.sql")

type SubtitlesDb* = distinct DbConn

#const HTACCESS =  slurp("../subtitles.htaccess")
var subtitlesDir = ""
proc createSubtitlesDirIfNeeded =
  if not subtitleDirCreated:
    subtitlesDir = publicDir / "subtitles"
    #createDir subtitlesDir
    #writeFile(subtitlesDir / ".htaccess", HTACCESS)
    subtitleDirCreated = true


proc createTable*(db: DbConn): SubtitlesDb =
  db.exec(sql SQL_STATEMENTS["create"])
  SubtitlesDb(db)

var ffmpeg = findExe("ffmpeg")
if ffmpeg == "":
  ffmpeg = findExe("aconv")

proc generateVttTrack(filename: string, destFile: string, streamIndex: int): int =
  let command = &"{ffmpeg} -y -i {quoteShell(filename)} -map 0:{streamIndex} -c:s webvtt -f webvtt {quoteShell(destFile)}"
  echo "command: ", command
  let ffmpegResult = execCmdEx(command)
  result = ffmpegResult.exitCode
  if result != 0:
    echo ffmpegResult.output


proc toSubtitleTrack(row: Row): SubtitleTrack =
  SubtitleTrack(
    uid: row[0],
    lang: row[1],
    title: row[2]
  )


proc getSubtitles*(subs: SubtitlesDb, entryUid: string): seq[SubtitleTrack] =
  let db = DbConn(subs)
  for row in db.rows(sql SQL_STATEMENTS["get"], entryUid):
    if row[0] == "": continue

    result.add toSubtitleTrack(row)

proc addSubtitleTrack*(subs: SubtitlesDb, mediaSource, entryUid, uid, lang, title: string, index: int) =
  createSubtitlesDirIfNeeded()
  let db = DbConn(subs)
  let count = try: parseInt db.getValue(sql SQL_STATEMENTS["entry-track-exists"], entryUid, lang, title)
    except:
      echo getCurrentExceptionMsg()
      0

  if count != 0: return

  let exitCode = generateVttTrack(
    mediaSource,
    subtitlesDir / uid,
    index
  )
  assert exitCode == 0
  if exitCode == 0:
    db.exec(sql SQL_STATEMENTS["add"], entryUid, uid, lang, title)

proc addSubtitleToPath*(subs: SubtitlesDb, trackSource, uid, lang, title: string, index: int) =
  createSubtitlesDirIfNeeded()
  let db = DbConn(subs)
  let count = try: parseInt db.getValue(sql SQL_STATEMENTS["track-exists"], lang, title)
    except:
      echo getCurrentExceptionMsg()
      0

  if count != 0: return


  let exitCode = generateVttTrack(
    trackSource,
    subtitlesDir / uid,
    index
  )
  assert exitCode == 0

  if exitCode == 0:
    let trackDir = title.splitFile()[0]
    #for row in db.getAllRows(sql SQL_STATEMENTS["debug-select"], uid, lang, title, trackDir & "%"):
    #  echo row
    db.exec(sql SQL_STATEMENTS["add-to-path"], uid, lang, title, trackDir & "%")


proc probeSubtitleTracks*(mediaSource: string): seq[tuple[uid, lang, title: string, index: int]] =
  #let db = DbConn(subs)
      
  let subtitles = ffprobe(mediaSource).subtitles

  for subtitleTrack in subtitles:
    result.add (genUid(), subtitleTrack.lang, subtitleTrack.title, subtitleTrack.index)

  
proc removeEntrySubtitles*(subs: SubtitlesDb, entryUid: string) =
  let db = DbConn(subs)
  for row in db.rows(sql SQL_STATEMENTS["remove-by-entry"], entryUid):
    let uid = row[0]
    # favoring remove orphan subtitles
    #removeFile(subtitlesDir / uid)


proc entriesUsingTrack*(subs: SubtitlesDb, trackUid: string): int =
  let db = DbConn(subs)
  parseInt db.getValue(sql SQL_STATEMENTS["inner-join-entry-count"], trackUid)


proc getEntrySubtitles*(subs: SubtitlesDb, entryUid: string): seq[SubtitleTrack] =
  let db = DbConn(subs)
  result = db.getAllRows(sql SQL_STATEMENTS["get"], entryUid).mapIt(SubtitleTrack(uid: it[0], lang: it[1], title: it[2]))

proc shareSubtitles*(subs: SubtitlesDb, ownerUid, receiverUid: string) =
  let db = DbConn(subs)
  db.exec(sql SQL_STATEMENTS["share-subtitles"], receiverUid, ownerUid)

proc removeOrphanSubtitles*(subs: SubtitlesDb) =
  createSubtitlesDirIfNeeded()
  
  for track in walkDir(subtitlesDir):
    let file = track[1].splitFile.name
    if file == ".htaccess":
      continue

    if subs.entriesUsingTrack(file) == 0:
      removeFile(subtitlesDir / file)
