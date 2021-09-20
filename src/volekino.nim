import volekino/globals
import asyncdispatch, os, db_sqlite, strutils, json, re, osproc#, asyncfile
from uri import nil
import prologue except newSettings, newApp
import prologue/websocket
#import mimetypes
import volekino/[userdata, models, config, library, ffmpeg]
import volekino/models/[db_appsettings, db_jobs, db_library, db_subtitles, db_users]
import json
from common/library_types import ConversionRequest
import common/user_types
import cligen

type SessionContext = ref object of Context
  sessionState: SessionState

when defined(windows):
  import winlean
else:
  import posix

const INDEX_HTML = slurp("../dist/index.html")

proc userGetSelf(ctx: SessionContext) {.async, gcsafe.} =
  let user = usersDb.getUser(ctx.sessionState)
  if user.id == -1:
    resp jsonResponse(%* {"error": "user not found"}, Http404)
  else:
    resp jsonResponse(% user)
  #resp jsonResponse(% ctx.sessionState.getUser())

proc postUsers(ctx: SessionContext) {.async.} =
  try:
    let request = parseJson(ctx.request.body).to(CreateUserRequest)
    let uid = usersDb.createOtpUser(allowAccountCreation=request.allowAccountCreation, isAdmin=request.isAdmin)
    resp jsonResponse(%* {"uid": uid}, Http200)
  except: resp jsonResponse(%* {"error": "could not parse create user request"}, Http400)

proc getAllUsers(ctx: SessionContext) {.async, gcsafe.} =
  resp jsonResponse(% usersDb.getAllUsers())

proc login(ctx: SessionContext) {.async.} =
  try:
    let credentials = parseJson(ctx.request.body)
    let username = credentials.getOrDefault("username").getStr()
    let password = credentials["password"].getStr()
    var sessionToken = ""
    if username.len == 0:
      sessionToken = usersDb.otpLogin(password)
    else:
      sessionToken = usersDb.basicLogin(username, password)
    if sessionToken == "":
      resp jsonResponse(%* {"error": "no matching username/password"}, Http401)
      return
    ctx.setCookie("session", sessionToken)
    resp "OK", Http200
  
  except:
    #echo getCurrentException()[]
    echo getCurrentExceptionMsg()
    resp jsonResponse(%* {"error": "incomplete login request"}, Http400)

proc registerUser(ctx: SessionContext) {.async.} =
  try:
    let sessionToken = ctx.request.cookies["session"]
    let credentials = parseJson(ctx.request.body)
    let username = credentials.getOrDefault("username").getStr()
    let password = credentials["password"].getStr()
    
    if username.len > 0 and password.len > 0:
      let sessionToken = usersDb.registerOtpUser(sessionToken, username, password)
      if sessionToken.len > 0:
        ctx.setCookie("session", sessionToken)
        resp "OK"
      else:
        resp jsonResponse(%* {"error": "session token is likely expired?"}, Http401)
    else:
      resp jsonResponse(%* {"error": "invalid username or password"}, Http400)
  except:
    resp jsonResponse(%* {"error": "could not parse request"}, Http400)
  

proc logout(ctx: SessionContext) {.async.} =
  ctx.setCookie("session", "")

proc libraryBase(ctx: SessionContext) {.async.} =
  var entryUid = ""
  try:
    entryUid = ctx.getPathParams("uid", "")
  except:
    discard

  if entryUid.len == 0:
    resp jsonResponse(% libraryDb.getAll())
  else:
    resp jsonResponse(% libraryDb.getEntry(entryUid))
  

proc getConversionStatistics(ctx: SessionContext) {.gcsafe, async.} =
  var entryUid = ""

  try:
    entryUid = ctx.getPathParams("uid", "")
  except:
    discard

  if entryUid.len == 0:
    resp jsonResponse(%* {"error": "id is required for conversion"}, Http400)
  else:
    resp jsonResponse(% conversionStatistics(libraryDb.getEntry(entryUid)))
  
  

proc jobStatus(ctx: SessionContext) {.async.} =
  var jobId = -1
  
  try:
    jobId = parseInt ctx.getPathParams("jobId", "-1")
  except:
    discard

  if jobId == -1:
    resp jsonResponse(%*{"error": "could not parse job id"}, Http400)
  else:
    resp jsonResponse(% jobsDb.jobStatus(jobId), Http200)


proc getSubtitles(ctx: SessionContext) {.async, gcsafe.} =
  let entryUid = ctx.getPathParams("uid", "")
  let subtitles = subtitlesDb.getEntrySubtitles(entryUid)
  if subtitles.len != 0 and subtitles[0].uid != "":
    resp jsonResponse(% subtitles, Http200)
  else :
    resp jsonResponse(%* [], Http404)
  

proc postConvert(ctx: SessionContext) {.async, gcsafe.} =
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

proc deleteMedia(ctx: SessionContext) {.async, gcsafe.} =
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

proc connectWebSocket(ctx: SessionContext) {.async, gcsafe.} =
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
    
    #if conf.requireAuth():
    template authenticateUser(requireAdmin=false, requireLogin=false): HandlerAsync {.dirty.}=
      block:
        proc factory: HandlerAsync =
          result = proc(ctx: SessionContext) {.async, gcsafe.} =
            let shouldRequireAdmin = requireAdmin
            let shouldRequireLogin = requireLogin
            try:
              let sessionToken = ctx.request.cookies["session"]
              echo "sessionToken = ",  sessionToken
              let session = usersDb.sessionAuthorizationState(sessionToken)
              ctx.sessionState = session
              if (shouldRequireLogin and not session.isLoggedIn) or (shouldRequireAdmin and not session.isAdmin):
                resp jsonResponse(%* {"error": "unauthorized"}, Http401)
              else:
                await switch(ctx)
            except KeyError:
              if shouldRequireLogin or shouldRequireAdmin:
                resp jsonResponse(%* {"error": "unauthorized"}, Http401)
              else:
                ctx.sessionState = EMPTY_SESSION
                await switch(ctx)

        factory()
        
    #[
      this causes a codegen error
    proc authenticateUser(requireAdmin=false, requireLogin=false): HandlerAsync = (
      proc (ctx: SessionContext) {.async, gcsafe.} =
        try:
          let sessionToken = ctx.request.cookies["session"]
          echo "sessionToken = ",  sessionToken
          let session = usersDb.sessionAuthorizationState(sessionToken)
          ctx.sessionState = session
          if (requireLogin and not session.isLoggedIn) or (requireAdmin and not session.isAdmin):
            resp jsonResponse(%* {"error": "unauthorized"}, Http401)
          else:
            await switch(ctx)
        except KeyError:
          if requireLogin or requireAdmin:
            resp jsonResponse(%* {"error": "unauthorized"}, Http401)
          else:
            ctx.sessionState = EMPTY_SESSION
            await switch(ctx)

    )
    ]#
      #app.use(authenticateUser())
    let requireAuth = conf.requireAuth()

    if usersDb.registeredCount == 0:
      let otp = usersDb.createOtpUser(allowAccountCreation=true, isAdmin=true)
      echo "One time password: ", otp

    var library = app.newGroup("/library", middlewares= @[authenticateUser(requireLogin=requireAuth)])
    library.get("/", libraryBase)
    library.get("/{uid}", libraryBase)
    library.get("/{uid}/subtitles", getSubtitles)
    library.get("/{uid}/conversion-statistics", getConversionStatistics)
    library.delete("/{id}", deleteMedia, middlewares= @[authenticateUser(requireAdmin=true)])
    app.get("/job-status/{jobId}", jobStatus)
    app.get("/users", getAllUsers, middlewares= @[authenticateUser(requireAdmin=true)])
    app.get("/users/me", userGetSelf, middlewares= @[authenticateUser()])
    app.post("/users", postUsers, middlewares= @[authenticateUser(requireAdmin=true)])
    #app.get("/user/me")
    app.addRoute("/ws", connectWebSocket, middlewares= @[authenticateUser(requireLogin=requireAuth)])
    app.post("/convert", postConvert, middlewares= @[authenticateUser(requireAdmin=true)])
    app.post("/login", login)
    app.post("/register", registerUser)
    app.post("/logout", logout)
    app.run(SessionContext)


dispatch(main)
