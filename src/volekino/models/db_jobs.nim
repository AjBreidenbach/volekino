import db_sqlite
import sqlite3
import strutils
import options
import tables

import util

const SQL_STATEMENTS = statementsFrom("./statements/jobs.sql")

type JobsDb* = distinct DbConn


var completionCallbacks = initTable[int, proc():void]()

proc addCompletionCallback*(jobId: int, cb: proc(): void) =
  completionCallbacks[jobId] = cb
  
proc createTable*(db: DbConn): JobsDb =
  db.exec(sql SQL_STATEMENTS["create"])
  JobsDb(db)


proc createJob*(jdb: JobsDb): int =
  let db = DbConn(jdb)
  db.exec(sql SQL_STATEMENTS["create-job"])

  result = int db.last_insert_row_id
  #echo "createJob ", result

proc updateJob*(jdb: JobsDb, jobId: int, progress: int, status: string="started") =
  let db = DbConn(jdb)
  db.exec(sql SQL_STATEMENTS["update-job"], progress, status, jobId)
  if status == "complete":
    try:
      completionCallbacks[jobId]()
    except KeyError:
      discard
  #echo "updateJob ", jobId, status, progress


proc errorJob*(jdb: JobsDb, jobId: int, status="error", error="") =
  let db = DbConn(jdb)
  db.exec(sql SQL_STATEMENTS["error"], status, error, jobId)
  #echo "errorJob ", jobId, status, error

type JobStatus* = object
  progress*: int
  status*: string
  error*: Option[string]

proc jobStatus*(jdb: JobsDb, jobId: int): JobStatus =
  let db = DbConn(jdb)
  let row = db.getRow(sql SQL_STATEMENTS["job-status"], jobId)

  if row[1] == "":
    return JobStatus(progress: -1, status: "inactive")

  result.status = row[0]
  result.progress = parseInt row[1]
  if row[2].len > 0:
    result.error = some(row[2])
  #echo "jobStatus: ", row

