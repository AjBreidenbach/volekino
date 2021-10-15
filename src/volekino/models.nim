import db_sqlite, os, globals
from models/db_appsettings import nil
from models/db_library import nil
from models/db_jobs import nil
from models/db_subtitles import nil
from models/db_users import nil
from models/db_downloads import nil

var appSettings*: db_appsettings.AppSettings
var libraryDb*: db_library.LibraryDb
var jobsDb*: db_jobs.JobsDb
var subtitlesDb*: db_subtitles.SubtitlesDb
var usersDb*: db_users.UsersDb
var downloadsDb*: db_downloads.DownloadDb
#var thumbnailsDb*: db_thumbnails.ThumbnailsDb
#export db_library.getAll, db_library.LibraryEntry, db_library.removeEntry, db_library.getEntry
#export db_appsettings.getProperty, db_appsettings.setProperty, db_appsettings.getAllProperties
#export db_jobs.createJob, db_jobs.updateJob, db_jobs.jobStatus


proc createTables*(db: DbConn) =
  appSettings = db_appsettings.createTable(db)
  jobsDb = db_jobs.createTable(db)
  #libraryDb = db_library.createTable(db)
  #subtitlesDb = db_subtitles.createTable(db)
  downloadsDb = db_downloads.createTable(db)
  usersDb = db_users.createUserTables(db)

proc createMediaTables*(db: DbConn) =
  libraryDb = db_library.createTable(db)
  subtitlesDb = db_subtitles.createTable(db)

proc initDb*(path: string, dbs = {0, 1}, retries = 3): tuple[defaultConn, mediaConn: DbConn] =
  try:
    if 0 in dbs:
      result[0] = open(path / "volekino.db", "", "", "")
      createTables(result[0])

    if 1 in dbs:
     result[1] = open(path / "volekino.db", "", "", "")
     createMediaTables(result[1])
  except DbError:
    if retries > 0:
      sleep 1000
      return initDb(path, dbs, retries - 1)
    else: echo "Could not initialize database ", getCurrentExceptionMsg()
    
template initTestDb*: untyped =
  import os

  createDir(getTempDir() / "volekino")
  
  let dbConn = open(getTempDir() / "volekino" / "volekino.db", "", "", "")
  createTables(
    dbConn
  )
