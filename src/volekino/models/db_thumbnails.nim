import util
import db_sqlite
import ../globals
#import ../uid
import os
import strformat
import osproc

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


proc generateThumbnailImage(filename: string, destFile: string, ffmpegTimestamp="00:00:01"): int =
  let command = &"{ffmpeg} -y -ss {ffmpegTimestamp} -i {quoteShell(filename)} -vf scale=384:216:force_original_aspect_ratio=decrease -vframes 1 -f image2 {quoteShell(destFile)}"
  echo "command: ", command
  let ffmpegResult = execCmdEx(command)
  result = ffmpegResult.exitCode
  if result != 0:
    echo ffmpegResult.output



var thumbnailsDir = ""


#const HTACCESS = slurp("../thumbnails.htaccess")
proc createThumbnailDirIfNeeded =
  if not thumbnailDirCreated:
    thumbnailsDir = publicDir / "thumbnails"
    #createDir(thumbnailsDir)
    #writeFile(thumbnailsDir / ".htaccess", HTACCESS)
    thumbnailDirCreated = true


proc createThumbnail*(mediaSource, uid: string) = #: string =
  createThumbnailDirIfNeeded()
  
  #let uid = genUid()
  let dest = thumbnailsDir / uid

  let exitCode = generateThumbnailImage(
    mediaSource,
    dest,
    #TODO make this parameter relative to duration
    ffmpegTimestamp="00:03:00"
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
