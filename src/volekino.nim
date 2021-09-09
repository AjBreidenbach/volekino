import volekino/globals
import asyncdispatch, os, db_sqlite, strutils, json, re, osproc#, asyncfile
from uri import nil
import prologue except newSettings, newApp
import prologue/websocket
#import mimetypes
import volekino/[userdata, models, config, library, ffmpeg]
import volekino/models/[db_appsettings, db_jobs, db_library, db_subtitles]
import json
from common/library_types import ConversionRequest
import cligen

when defined(windows):
  import winlean
else:
  import posix

const INDEX_HTML = slurp("../dist/index.html")


proc libraryBase(ctx: Context) {.async.} =
  var entryUid = ""
  try:
    entryUid = ctx.getPathParams("uid", "")
  except:
    discard

  if entryUid.len == 0:
    resp jsonResponse(% libraryDb.getAll())
  else:
    resp jsonResponse(% libraryDb.getEntry(entryUid))
  

proc getConversionStatistics(ctx: Context) {.gcsafe, async.} =
  var entryUid = ""

  try:
    entryUid = ctx.getPathParams("uid", "")
  except:
    discard

  if entryUid.len == 0:
    resp jsonResponse(%* {"error": "id is required for conversion"}, Http400)
  else:
    resp jsonResponse(% conversionStatistics(libraryDb.getEntry(entryUid)))
  
  

proc jobStatus(ctx: Context) {.async.} =
  var jobId = -1
  
  try:
    jobId = parseInt ctx.getPathParams("jobId", "-1")
  except:
    discard

  if jobId == -1:
    resp jsonResponse(%*{"error": "could not parse job id"}, Http400)
  else:
    resp jsonResponse(% jobsDb.jobStatus(jobId), Http200)


proc getSubtitles(ctx: Context) {.async, gcsafe.} =
  let entryUid = ctx.getPathParams("uid", "")
  let subtitles = subtitlesDb.getEntrySubtitles(entryUid)
  if subtitles.len != 0 and subtitles[0].uid != "":
    resp jsonResponse(% subtitles, Http200)
  else :
    resp jsonResponse(%* [], Http404)
  

proc postConvert(ctx: Context) {.async, gcsafe.} =
  var conversionRequest: ConversionRequest
  try:
    conversionRequest = (parseJson ctx.request.body).to(ConversionRequest)
  except:
    resp jsonResponse(%*{"error": "could not parse request"},Http400)
      
  

  #[
  let sourceEntry = libraryDb.getEntry(conversionRequest.entryUid)
  let path = sourceEntry.path
  let (ffmpegResult, processFuture) = ffmpegProcess(libraryDir / path, videoEncoding=conversionRequest.videoEncoding, audioEncoding=conversionRequest.audioEncoding, container=conversionRequest.container)

  proc ffmpegCallback(f: Future[void]) {.gcsafe.} =
    asyncCheck f
    let libraryRelativeDir = path.splitFile[0]
    addToLibrary(libraryRelativeDir / ffmpegResult.filename,libraryDir, tmpDir)

    if conversionRequest.removeOriginal:
      try:
        removeFile(libraryDir / path)
        libraryDb.removeEntry(sourceEntry.id)
      except:
        echo "failed to remove file ", libraryDir / path

  processFuture.addCallback(ffmpegCallback)
  ]#

  let jobId = convertMedia(conversionRequest)
  resp jsonResponse(%*{"jobId": jobId}, Http200)

proc deleteMedia(ctx: Context) {.async, gcsafe.} =
  var entryUid = ""
  try:
    entryUid = ctx.getPathParams("id", "-1")
  except:
    discard


  if entryUid.len == 0:
    resp jsonResponse(%*{"error": "could not parse library entry id"}, Http400)
  else:
    let entry = libraryDb.getEntry(entryUid)

    if entry.uid.len == 0:
      resp jsonResponse(%* {"error": "no such entry"}, Http404)
      return

    try:
      removeFile(libraryDir / entry.path)
      libraryDb.removeEntry(entry.uid)

      resp jsonResponse(%* {"error": nil}, Http200)
    except:
      
      resp jsonResponse(%* {"error": "could not remove entry " & getCurrentExceptionMsg()}, Http500)
    

var websocketConnections = newSeq[WebSocket]()

proc broadcast(index: int, message: string): Future[void] =
  var futures = newSeq[Future[void]]()
  for (i, connection) in websocketConnections.pairs():
    if i == index or connection.isNil: continue
    futures.add connection.send(message)


  all(futures)

proc connectWebSocket(ctx: Context) {.async, gcsafe.} =
  #await sleepAsync 200
  let ws = await newWebSocket(ctx)
  await ws.send($ websocketConnections.len)
  let index = websocketConnections.len
  #if not ws.isNil: websocketConnections.add ws
  websocketConnections.add ws
  while ws.readyState == Open:
    try:
      let packet = await ws.receiveStrPacket()
      await index.broadcast(packet)
    except: break

  websocketConnections[websocketConnections.find(ws)] = nil
  #echo "connections: ", websocketConnections.len

  resp "OK"

proc initDb() =
  let db = open(globals.dbPath, "", "", "")
  createTables(db)
  

proc httpdExecutable: string =
  for exeName in ["httpd", "apache2"]:
    result = findExe(exeName)
    if result.len > 0: break



proc startHttpd: Process =
  let env = newStringTable({"USER": getEnv("USER"), "USER_DATA_DIR": USER_DATA_DIR, "APACHE_MODULES_DIR": "/usr/lib/apache2/modules/"})
  let command = httpdExecutable()
  if command.len > 0:
    echo "starting httpd"
    result = startProcess(command, USER_DATA_DIR, args=["-d", USER_DATA_DIR, "-f", "httpd.conf"], options = {poDaemon, poStdErrToStdOut, poParentStreams, poEchoCmd}, env=env)

proc main(api=true, apache=true, sync=true, printDataDir=false, populateUserData=true) =
  if printDataDir:
    echo USER_DATA_DIR
    quit 0
  echo "running with ", commandLineParams()
  #createDir(staticDir)
  #createDir(USER_DATA_DIR / "logs")

  if populateUserData:
    userdata.populateFromZip()

  #when(defined(release)):
  if not fileExists(staticDir / "index.html"):
    createDir(staticDir)
    when defined(release):
      writeFile(staticDir / "index.html", INDEX_HTML)
    else:
      try:
        if getAppDir().endsWith "dist":
          createSymLink(getAppDir()  / "index.html", staticDir / "index.html")
        else:
          createSymLink(getAppDir() / "dist" / "index.html", staticDir / "index.html")
      except: discard
    
  initDb()
  
  

  let conf = loadConfig(appSettings)

  if sync:
    echo "syncing... this may take a while"
    conf.syncMedia()
    conf.syncSubtitles()

  var httpdProcess: Process
  if apache:
    httpdProcess = startHttpd()

  let prologueSettings = prologue.newSettings(port = conf.port)
  
  let httpdShutdown = initEvent(
    proc() {.closure, gcsafe.} =
      let pid = cint parseInt(strip readFile(USER_DATA_DIR / "httpd.pid"))
      when defined(windows):
        #TODO kill apache
        echo "not killing apache on windows???"
      else:
        let status = kill(pid, SIGTERM)
        echo "terminate apache ", $status
        
      httpdProcess.terminate()
      echo "httpd exit status ", httpdProcess.waitForExit()
      httpdProcess.close()
      
  )

  if api:
    var shutdown = newSeq[prologue.Event]()
    if apache:
      shutdown.add httpdShutdown

    var app = prologue.newApp(prologueSettings, shutdown = shutdown)
    

    app.get("/library", libraryBase)
    app.get("/library/{uid}", libraryBase)
    app.get("/library/{uid}/subtitles", getSubtitles)
    app.get("/library/{uid}/conversion-statistics", getConversionStatistics)
    app.get("/job-status/{jobId}", jobStatus)
    app.addRoute("/ws", connectWebSocket)
    app.post("/convert", postConvert)
    app.delete("/library/{id}", deleteMedia)
    app.run()


dispatch(main)
