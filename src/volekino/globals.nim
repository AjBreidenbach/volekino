import appdirs, os, osproc, asyncdispatch
import transmission_remote
import strtabs, strutils

let 
  APP* = application("VoleKino", "Andrew Breidenbach")
  USER_DATA_DIR* = user_data APP
  publicDir* = USER_DATA_DIR / "public"
  libraryDir* = joinPath(USER_DATA_DIR, "public", "library")
  mediaDir* = USER_DATA_DIR / "media"
  MEDIA_DIR* = mediaDir
  staticDir* = joinPath(USER_DATA_DIR, "public", "static")
  tmpDir* = getTempDir() / "volekino"
  TMP_DIR* = tmpDir
  dbPath* = joinPath(USER_DATA_DIR, "volekino.db")
  VOLEKINO_PID* = USER_DATA_DIR / "volekino.pid"
  VOLEKINO_STATUS* = TMP_DIR / "volekino_daemon"


when defined(windows):
  import psutil/psutil_windows
else:
  import psutil/psutil_linux




var mediaDirCreated*, libraryDirCreated*, thumbnailDirCreated*, subtitleDirCreated* = false

var transmission*: TransmissionRemote


type ShutdownHandler* = proc(): void {.gcsafe, closure.}
var shutdownHandlers* = newSeq[ShutdownHandler]()

#proc addShutdownHandler*(f: ShutdownHandler) =
#  shutdownHandlers.add f

proc runShutdownHandlers =
  for f in shutdownHandlers:
    f()

proc invokeSelf*(args: varargs[string]): Process =
  let command = getAppFilename()
  var env = newStringTable({"VOLEKINO_DAEMON": ""})
  for (key, value) in envPairs():
    env[key] = value
  startProcess(command, args=args, options={poEchoCmd, poParentStreams, poDaemon, poUsePath}, env=env)
  

proc restart* =
  runShutdownHandlers()
  writeFile VOLEKINO_STATUS, "restart"

proc shutdown* =
  runShutdownHandlers()
  writeFile VOLEKINO_STATUS, "shutdown"


proc clearDaemonStatus* =
  removeFile VOLEKINO_STATUS

proc getDaemonStatus*: string =
  result = try:
    strip(readFile VOLEKINO_STATUS)
  except: ""

proc writePID*(pid: int | cint) =
  writeFile(VOLEKINO_PID, $pid)

proc clearPID* =
  removeFile(VOLEKINO_PID)

proc volekinoIsRunning*: bool =
  try:
    let pid = parseInt readFile(VOLEKINO_PID)
    pid_name(pid) == "volekino"
  except: false


var syncing* = true
proc runSync* =
  syncing = true
  #let command = getAppFilename()
  #echo "syncCommand = ", command
#proc main(api=true, apache=true, transmission=false, sync=true, printDataDir=false, populateUserData=true) =
  #let syncProcess = startProcess(command, args=["--syncOnly=true"], options={poEchoCmd, poParentStreams, poDaemon})
  let syncProcess = invokeSelf("--syncOnly=true")

  addProcess(
    syncProcess.processId,
    proc(fd: AsyncFd): bool =
      echo "sync process exited with ", $syncProcess.peekExitCode()
      syncing = false
      true
  )


proc initTransmissionRemote* =
  transmission = newTransmissionRemote(port=9092)
