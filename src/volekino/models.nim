import db_sqlite
from models/db_appsettings import nil
from models/db_library import nil
from models/db_jobs import nil
from models/db_subtitles import nil
#from models/db_thumbnails import nil

var appSettings*: db_appsettings.AppSettings
var libraryDb*: db_library.LibraryDb
var jobsDb*: db_jobs.JobsDb
var subtitlesDb*: db_subtitles.SubtitlesDb
#var thumbnailsDb*: db_thumbnails.ThumbnailsDb
#export db_library.getAll, db_library.LibraryEntry, db_library.removeEntry, db_library.getEntry
#export db_appsettings.getProperty, db_appsettings.setProperty, db_appsettings.getAllProperties
#export db_jobs.createJob, db_jobs.updateJob, db_jobs.jobStatus


proc createTables*(db: DbConn) =
  appSettings = db_appsettings.createTable(db)
  libraryDb = db_library.createTable(db)
  jobsDb = db_jobs.createTable(db)
  subtitlesDb = db_subtitles.createTable(db)
  #thumbnailsDb = db_thumbnails.createTable(db)
  echo "tables created"

template initTestDb*: untyped =
  import os

  createDir(getTempDir() / "volekino")
  
  let dbConn = open(getTempDir() / "volekino" / "volekino.db", "", "", "")
  createTables(
    dbConn
  )
