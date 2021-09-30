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

proc initDb*(path: string): tuple[defaultConn, mediaConn: DbConn] =
  result[0] = open(USER_DATA_DIR / "volekino.db", "", "", "")
  result[1] = open(USER_DATA_DIR / "volekino_m.db", "", "", "")

  createTables(result[0])
  createMediaTables(result[0])
  
template initTestDb*: untyped =
  import os

  createDir(getTempDir() / "volekino")
  
  let dbConn = open(getTempDir() / "volekino" / "volekino.db", "", "", "")
  createTables(
    dbConn
  )
