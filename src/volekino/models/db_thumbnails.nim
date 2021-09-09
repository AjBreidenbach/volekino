import util
import db_sqlite
import ../globals
#import ../uid
import os
import strformat
import osproc
import ../ffprobe

import db_library

const SQL_STATEMENTS = statementsFrom("./statements/thumbnails.sql")

var ffmpeg = findExe("ffmpeg")
if ffmpeg == "":
  ffmpeg = findExe("aconv")

type ThumbnailsDb* = distinct DbConn

proc createTable*(db: DbConn): ThumbnailsDb =
  db.exec(sql SQL_STATEMENTS["create"])
  ThumbnailsDb(db)


proc getThumbnail*(thumbs: ThumbnailsDb, id: int): string =
  let db = DbConn(thumbs)
  db.getValue(sql SQL_STATEMENTS["get"], id)


proc addThumbnail*(thumbs: ThumbnailsDb, id: int, uid: string) =
  let db = DbConn(thumbs)
  db.exec(sql SQL_STATEMENTS["add"], id)


proc toFfmpegTimestamp(t: int): string =
  let seconds = t mod 60
  let minutes = t div 60 mod 60
  let hours = t div 3600 mod 3600

  if hours < 10: result.add '0'
  result.add $hours
  result.add ':'
  if minutes < 10: result.add '0'
  result.add $minutes
  result.add ':'
  if seconds < 10: result.add '0'
  result.add $seconds
  

proc generateThumbnailImage(filename: string, destFile: string, time: int): int =
  let ffmpegTimestamp = toFfmpegTimestamp(time)
  let command = &"{ffmpeg} -y -ss {ffmpegTimestamp} -i {quoteShell(filename)} -vf scale=384:216:force_original_aspect_ratio=decrease -vframes 1 -f image2 {quoteShell(destFile)}"
  echo "command: ", command
  let ffmpegResult = execCmdEx(command)
  result = ffmpegResult.exitCode
  if result != 0:
    echo ffmpegResult.output



var thumbnailsDir = ""


proc createThumbnailDirIfNeeded =
  if not thumbnailDirCreated:
    thumbnailsDir = publicDir / "thumbnails"
    #createDir(thumbnailsDir)
    thumbnailDirCreated = true


proc createThumbnail*(mediaSource, uid: string) = #: string =
  createThumbnailDirIfNeeded()
  
  #let uid = genUid()
  let dest = thumbnailsDir / uid
  let duration = ffprobe(mediaSource).duration
  let thumbnailTime = if duration < 720: # 12 minutes
    duration div 3
  else: 180 # 3 minutes


  let exitCode = generateThumbnailImage(
    mediaSource,
    dest,
    #TODO make this parameter relative to duration
    thumbnailTime
  )
  
  assert exitCode == 0
       

proc removeOrphanThumbnails*(library: LibraryDb) =
  createThumbnailDirIfNeeded()

  for thumbnail in walkDir(thumbnailsDir):
    let file = thumbnail[1].splitFile.name
    if file == ".htaccess":
      continue


    if not library.hasEntry(file):
      removeFile(thumbnailsDir / file)
      

    

#[

proc removeThumbnail*(thumbs: ThumbnailsDb, id: int) =
  let db = DbConn(thumbs)
  let uid = db.getValue(sql SQL_STATEMENTS["remove"], id)

  removeFile(thumbnailsDir / uid)
  
  ]#
