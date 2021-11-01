import db_sqlite
import sqlite3
import strutils
import json
import tables

import util

const SQL_STATEMENTS = statementsFrom("./statements/jobs.sql")

type JobsDb* = distinct DbConn

type JobStatus* = object
  progress*: int
  status*: string
  data*: string


var completionCallbacks = initTable[int, proc():void]()

proc addCompletionCallback*(jobId: int, cb: proc(): void) =
  completionCallbacks[jobId] = cb
  
proc createTable*(db: DbConn): JobsDb =
  db.exec(sql SQL_STATEMENTS["create"])
  JobsDb(db)


proc createJob*(jdb: JobsDb, data: string | JsonNode = ""): int =
  let db = DbConn(jdb)
  db.exec(sql SQL_STATEMENTS["create-job"])

  result = int db.last_insert_row_id
  #echo "createJob ", result

  when type(data) is string:
    if data.len > 0:
      db.exec(sql SQL_STATEMENTS["data"], "", data, result)
  else:
    db.exec(sql SQL_STATEMENTS["data"], "", data, result)

proc updateJob*(jdb: JobsDb, jobId: int, progress: int, status: string="started") =
  let db = DbConn(jdb)
  db.exec(sql SQL_STATEMENTS["update-job"], progress, status, jobId)
  if status == "complete":
    try:
      completionCallbacks[jobId]()
    except KeyError:
      discard
  #echo "updateJob ", jobId, status, progress


proc jobStatus*(jdb: JobsDb, jobId: int): JobStatus =
  let db = DbConn(jdb)
  let row = db.getRow(sql SQL_STATEMENTS["job-status"], jobId)

  if row[1] == "":
    return JobStatus(progress: -1, status: "inactive")

  result.status = row[0]
  result.progress = parseInt row[1]
  result.data = row[2]
  #if row[2].len > 0:
  #  result.error = some(row[2])
  #echo "jobStatus: ", row

proc errorJob*(jdb: JobsDb, jobId: int, status="error", error="") =
  let db = DbConn(jdb)

  let currentStatus = jdb.jobStatus(jobId)
  var dataObj = if currentStatus.data.len > 0:
    try:
      var tmp = parseJson(currentStatus.data)
      if tmp.kind == JObject:
        tmp
      else:
        var tmp2 = newJObject()
        tmp2["data"] = tmp
        tmp2
    except:
      var tmp = newJObject()
      tmp["data"] = % currentStatus.data
      tmp
  else: newJObject()
    
  dataObj["error"] = %error
  db.exec(sql SQL_STATEMENTS["data"], status, dataObj, jobId)
  #echo "errorJob ", jobId, status, error


