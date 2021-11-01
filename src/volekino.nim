import volekino/globals
import asyncdispatch, asyncfile, os, db_sqlite, sqlite3, strutils, json, osproc, uri, base64
import prologue except newSettings, newApp
import prologue/websocket
#import mimetypes
import volekino/[userdata, models, config, library, ffmpeg, gui, parse_settings, pipe, file_navigation]
import volekino/models/[db_appsettings, db_jobs, db_library, db_subtitles, db_users, db_downloads]
import volekino/daemons/[httpd, transmissiond, ssh]
import json
import common/library_types
import common/user_types
import options, times, terminal
import cligen


var conf: VoleKinoConfig

type SessionContext = ref object of Context
  sessionState: SessionState


proc decodePath*(p: string): string =
  base64.decode(p.replace('.', '='))

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

proc getDownloads(ctx: SessionContext) {.async.} =
  let downloads = downloadsDb.getDownloads()
  resp jsonResponse(% downloads)

proc getLog(ctx: SessionContext) {.async, gcsafe.} =
  let
    logname = ctx.getPathParams("logname", "volekino")
    filename = case logname:
    of "apache": "error_log"
    of "transmission", "ssh": logname
    else: "volekino"
  var log = openAsync(LOG_DIR / filename, fmRead)
  let contents = await readAll(log)

  # workaround until added deserialize to mithril wrapper
  resp jsonResponse(%* {"contents": contents})
      
proc getSystemFiles(ctx: SessionContext) {.async, gcsafe.} =
  let requestedPath = decodePath(ctx.getPathParams("path", ""))

  resp jsonResponse(% file_navigation.ls(requestedPath))


proc postSystemFiles(ctx: SessionContext) {.async, gcsafe.} =
  let requestedPath = decodePath(ctx.getPathParams("path", ""))
  try:
    symlinkMedia(requestedPath)
    resp jsonResponse(%* {"error": nil})
  except OsError, RecursiveLibraryError:
    resp jsonResponse(%* {"error": getCurrentExceptionMsg()}, Http500)
  #resp jsonResponse(%* {"error": nil})
  
proc getSharedMedia(ctx: SessionContext) {.async, gcsafe.} =
  resp jsonResponse(% (await library.getSharedMedia()))

proc deleteSharedMedia(ctx: SessionContext) {.async, gcsafe.} =
  let requestedMedia = decodePath(ctx.getPathParams("media", ""))
  try:
    library.removeSharedMedia(downloadsDb, requestedMedia)
    resp jsonResponse(%* {"error": nil})
  except:
    resp jsonResponse(%* {"error": getCurrentExceptionMsg()}, Http500)

proc postRestart(ctx: SessionContext) {.async, gcsafe.} =
  resp "OK"
  restart()

proc postShutdown(ctx: SessionContext) {.async, gcsafe.} =
  resp "OK"
  shutdown()


#[
proc runSync =
  let command = getAppFilename()
  echo "syncCommand = ", command
#proc main(api=true, apache=true, transmission=false, sync=true, printDataDir=false, populateUserData=true) =
  let syncProcess = startProcess(command, args=["--syncOnly=true"], options={poEchoCmd, poParentStreams, poDaemon})

  addProcess(
    syncProcess.processId,
    proc(fd: AsyncFd): bool =
      echo "sync process exited with ", $syncProcess.peekExitCode()
      true
  )
]#

proc postDownloads(ctx: SessionContext) {.async, gcsafe.} =
  try:
    let request = parseJson(ctx.request.body).to(DownloadRequest)
    let jobId = await downloadsDb.createDownload(url=request.url)
    jobId.addCompletionCallback runSync
      
    
    resp jsonResponse(%* {"jobId": jobId})
  except: resp jsonResponse(%* {"error": "could not create download"}, Http400)


proc getSettings(ctx: SessionContext) {.async, gcsafe.} =
  resp jsonResponse(% conf.getSettings())

proc postSettings(ctx: SessionContext) {.async, gcsafe.} =
  try:
    let request = parseJson(ctx.request.body).to(ApplySettingsRequest)
    conf.applySettings(request)
    resp "OK"
  except: resp jsonResponse(%* {"error": "could not parse settings change request"}, Http400)


proc getAllUsers(ctx: SessionContext) {.async, gcsafe.} =
  resp jsonResponse(% usersDb.getAllUsers())

proc login(ctx: SessionContext) {.async, gcsafe.} =
  try:
    let credentials = parseJson(ctx.request.body)
    let username = credentials.getOrDefault("username").getStr()
    let password = credentials["password"].getStr()
    var sessionToken = ""
    if username.len == 0:
      sessionToken = usersDb.otpLogin(password, conf.otpExpirationPeriod)
    else:
      sessionToken = usersDb.basicLogin(username, password)
    if sessionToken == "":
      let error = if username.len > 0: "no matching username/password" else: "no matching password, or password is expired"
      resp jsonResponse(%* {"error": error}, Http401)
      return
    ctx.setCookie("session", sessionToken, path="/", maxAge=some(conf.sessionDuration()))
    resp "OK", Http200
  
  except:
    resp jsonResponse(%* {"error": "incomplete login request"}, Http400)

proc registerUser(ctx: SessionContext) {.async, gcsafe.} =
  try:
    let sessionToken = ctx.request.cookies["session"]
    let credentials = parseJson(ctx.request.body)
    let username = credentials.getOrDefault("username").getStr()
    let password = credentials["password"].getStr()
    
    if username.len > 0 and password.len > 0:
      let sessionToken = usersDb.registerOtpUser(sessionToken, username, password, conf.sessionDuration)
      if sessionToken.len > 0:
        ctx.setCookie("session", sessionToken, path="/", maxAge=some(conf.sessionDuration()))
        resp "OK"
      else:
        resp jsonResponse(%* {"error": "this user is not able to register or session token is expired"}, Http401)
    else:
      resp jsonResponse(%* {"error": "invalid username or password"}, Http400)
  except:
    resp jsonResponse(%* {"error": "could not parse request"}, Http400)
  

proc logout(ctx: SessionContext) {.async.} =
  ctx.setCookie("session", "", path="/")

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

#[
proc initDb(): DbConn =
  result = open(globals.dbPath, "", "", "")
  createTables(result)
  
]#

proc httpdExecutable: string =
  for exeName in ["httpd", "apache2"]:
    result = findExe(exeName)
    if result.len > 0: break


proc shouldWriteIndex(): bool =
  let indexPath = staticDir / "index.html"
  if fileExists(indexPath):
    let info = getFileInfo(indexPath, followSymlink = false)

    if info.kind != pcLinkToFile:
      let binLastWrite = getFileInfo(getAppFilename()).lastWriteTime
      result = binLastWrite > info.lastWriteTime
  else: result = true

proc writeIndex() =
  const INDEX_HTML = slurp("../dist/index.html")
  when defined(release):
    writeFile(staticDir / "index.html", INDEX_HTML)
  else:
    try:
      removeFile(staticDir / "index.html")
      if getAppDir().endsWith "dist":
        createSymLink(getAppDir()  / "index.html", staticDir / "index.html")
      else:
        createSymLink(getAppDir() / "dist" / "index.html", staticDir / "index.html")
    except: discard

var run = 0

proc applyInputSettings =
  discard initDb(USER_DATA_DIR, dbs={0})
  var inputBuffer = ""
  while not endOfFile(stdin):
    inputBuffer.add stdin.readLine

  for (key, value) in parseSettings(inputBuffer):
    appSettings.setProperty(key, value)

proc main(
  api=true,
  apache=true,
  transmission=true,
  sync=true,
  gui=false,
  printDataDir=false,
  populateUserData=true,
  syncOnly=false,
  guiOnly=false,
  tunnelOnly=false,
  settings=false,
  e=false
  ) =
  inc run
  if printDataDir:
    echo USER_DATA_DIR
    quit 0
      



  if populateUserData:
    #echo "populateUserData"
    try:
      userdata.populateFromZip()
      createDir(LOG_DIR)

      createDir(USER_DATA_DIR / "conf")

      # apache doesn't work on termux without this
      createSymLink(USER_DATA_DIR / "mime.types", USER_DATA_DIR / "conf" / "mime.types")

    except:
      # this is expected to fail after the first run
      discard
      #styledecho fgRed, getCurrentExceptionMsg()
      


  if syncOnly:
    echo "syncing... this may take a while"
    var 
      dbConn: DbConn
      exitStatus = 0
    while true:
      try:
        dbConn = initDb(USER_DATA_DIR)[1]
        conf = loadConfig(appSettings)
        conf.syncMedia()
        conf.syncSubtitles()
        exitStatus = 0
      except DbError:
        echo getCurrentExceptionMsg()
        #echo "here ", PSqlite3(dbConn).errcode()
        exitStatus = PSqlite3(dbConn).errcode()

      if exitStatus != 7 and exitStatus != 5: break
      sleep 1000
        
    quit exitStatus
  elif guiOnly:
    try:
      discard initDb(USER_DATA_DIR, dbs={0})
    except:
      styledecho fgRed, "couldn't open db to create session ", getCurrentExceptionMsg()
    launchWebview()
    return
  elif tunnelOnly:
    try:
      discard initDb(USER_DATA_DIR, dbs={0})
      conf = loadConfig(appSettings)
    except:
      styledecho fgRed, "couldn't open db to create tunnel? ", getCurrentExceptionMsg()
    discard conf.startSshTunnel()
    return
  if existsEnv("VOLEKINO_DAEMON"):
    discard initDb(USER_DATA_DIR)
    assert not appSettings.isNil
    conf = loadConfig(appSettings)
  elif volekinoIsRunning():
    if sync:
      runSync()
    if gui:
      startGui()
    if settings:
      applyInputSettings()
      restart()

    return
  else:
    let VOLEKINO_OPT = when defined(termux):
      getEnv("PREFIX") / ".." / "opt" / "volekino" / "bin"
    else: "/" / "opt" / "volekino" / "bin"
    putEnv "PATH", VOLEKINO_OPT & ':' & getEnv("PATH")

    clearDaemonStatus()
    var params = commandLineParams()
    params.add "--populateUserData=off"
    if run > 1:
      params.add "--gui=off"
    elif settings:
      applyInputSettings()
    let
      daemon = invokeSelf(e, params)

    if not e: asyncCheck asyncPipe(daemon, LOG_DIR / "volekino")

    writePID(daemon.processId)
    while daemon.running:
      if e:
        sleep 1000
      else:
        poll(1000)
      case getDaemonStatus():
      of "restart":
        styledecho fgRed, "restart"
        #addProcess(
        #  daemon.processId,
        #  proc (f: AsyncFd): bool {.closure, gcsafe.} =
        #    dispatch(main)
        #    true
        #)

        daemon.terminate()
        echo "child exited with ", daemon.waitForExit()
        sleep 1000 # better to check ports?
        dispatch(main)
        return
        
      of "shutdown":
        styledecho fgRed, "shutdown"
        clearPID()
        daemon.terminate()
        return
        
      #try: sleep 1000
      #except: discard

    echo "daemon exited with ", daemon.waitForExit()


  if shouldWriteIndex():
    writeIndex()
    

  var httpdProcess, sshProcess, transmissionProcess: Process
  var apacheShutdownHandler, sshShutdownHandler, transmissionShutdownHandler: ShutdownHandler
  if apache:
    httpdProcess = conf.startHttpd()
    apacheShutdownHandler = proc {.gcsafe} =
      shutdownHttpd(httpdProcess)
    shutdownHandlers.add apacheShutdownHandler
    
    let proxyServer = conf.proxyServer
    if proxyServer.len > 0:
      sshProcess = invokeSelf("--tunnelOnly", "--populateUserData=off")
      sshShutdownHandler = proc {.gcsafe.} =
        sshProcess.terminate()
      shutdownHandlers.add sshShutdownHandler
      
      
  if transmission:
    initTransmissionRemote()
    transmissionProcess = conf.startTransmissionD()
    transmissionShutdownHandler = proc {.gcsafe.} =
      shutdownTransmissionD(transmissionProcess)
    shutdownHandlers.add(transmissionShutdownHandler)

    let restartDownloads = sleepAsync(2000)
    restartDownloads.addCallback do:
      downloadsDb.resumeDownloads()

  let prologueSettings = prologue.newSettings(port = conf.port)


  if api:
    var shutdown = newSeq[prologue.Event]()
    for f in shutdownHandlers:
      shutdown.add initEvent(f)

    var app = prologue.newApp(prologueSettings, shutdown = shutdown)
    
    template authenticateUser(requireAdmin=false, requireLogin=false): HandlerAsync {.dirty.}=
      block:
        proc factory: HandlerAsync =
          result = proc(ctx: SessionContext) {.async, gcsafe.} =
            let shouldRequireAdmin = requireAdmin
            let shouldRequireLogin = requireLogin
            try:
              let sessionToken = ctx.request.cookies["session"]
              #echo "sessionToken = ",  sessionToken
              let session = usersDb.sessionAuthorizationState(sessionToken, conf.sessionDuration)
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
        
        #app.use(authenticateUser())
    let requireAuth = conf.requireAuth()

    #[
    let restartMiddleWare: HandlerAsync = proc (ctx: SessionContext) {.async, gcsafe.} =
      await switch(ctx)
      restart()
    ]#


    if usersDb.registeredCount == 0:
      let otp = usersDb.createOtpUser(allowAccountCreation=true, isAdmin=true)
      styledecho fgYellow, styleBright, "One time password: ", otp

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
    app.get("/settings", getSettings, middlewares= @[authenticateUser(requireAdmin=true)])
    app.post("/settings", postSettings, middlewares= @[authenticateUser(requireAdmin=true)])
    app.addRoute("/ws", connectWebSocket, middlewares= @[authenticateUser(requireLogin=requireAuth)])
    app.post("/convert", postConvert, middlewares= @[authenticateUser(requireAdmin=true)])
    app.post("/login", login)
    app.get("/files", getSystemFiles, middlewares= @[authenticateUser(requireAdmin=true)])
    app.get("/files/{path}", getSystemFiles, middlewares= @[authenticateUser(requireAdmin=true)])
    app.post("/files/{path}", postSystemFiles, middlewares= @[authenticateUser(requireAdmin=true)])
    app.get("/shared-media", getSharedMedia, middlewares= @[authenticateUser(requireAdmin=true)])
    app.delete("/shared-media/{media}", deleteSharedMedia, middlewares= @[authenticateUser(requireAdmin=true)])
    app.get("/downloads", getDownloads, middlewares= @[authenticateUser(requireLogin=requireAuth)])
    app.get("/logs/{logname}", getLog, middlewares=(@[authenticateUser(requireAdmin=true)]))
    app.post("/downloads", postDownloads, middlewares= @[authenticateUser(requireAdmin=true)])
    app.post("/register", registerUser)
    app.post("/restart", postRestart, middlewares= @[authenticateUser(requireAdmin=true)])
    #app.post("/shutdown", postShutdown)#, middlewares= @[restartMiddleWare])
    app.post("/logout", logout)
    if sync:
      runSync()
    if gui:
      startGui()
    app.run(SessionContext)

  if sync:
    runSync()

if existsEnv("SSH_ASKPASS"):
  discard initDb(USER_DATA_DIR, {0}, retries=1)
  conf = loadConfig(appSettings)
  let pwd = conf.getProxyPassword()
  echo pwd
else:
  dispatch(main)
