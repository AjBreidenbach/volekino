import db_sqlite
import sqlite3
import strutils

import util

const SQL_STATEMENTS = statementsFrom("./statements/jobs.sql")

type JobsDb* = distinct DbConn


proc createTable*(db: DbConn): JobsDb =
  db.exec(sql SQL_STATEMENTS["create"])
  JobsDb(db)


proc createJob*(jdb: JobsDb): int =
  let db = DbConn(jdb)
  db.exec(sql SQL_STATEMENTS["create-job"])

  result = int db.last_insert_row_id
  echo "createJob ", result

proc updateJob*(jdb: JobsDb, jobId: int, progress: int, status: string="started") =
  let db = DbConn(jdb)
  db.exec(sql SQL_STATEMENTS["update-job"], progress, status, jobId)
  echo "updateJob ", jobId, status, progress


type JobStatus* = object
  progress*: int
  status*: string

proc jobStatus*(jdb: JobsDb, jobId: int): JobStatus =
  let db = DbConn(jdb)
  let row = db.getRow(sql SQL_STATEMENTS["job-status"], jobId)

  if row[1] == "":
    return JobStatus(progress: -1, status: "inactive")

  result.status = row[0]
  result.progress = parseInt row[1]

