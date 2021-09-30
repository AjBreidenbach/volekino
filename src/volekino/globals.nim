import appdirs, os, osproc, asyncdispatch
import transmission_remote

let 
  APP* = application("VoleKino", "Andrew Breidenbach")
  USER_DATA_DIR* = user_data APP
  publicDir* = USER_DATA_DIR / "public"
  libraryDir* = joinPath(USER_DATA_DIR, "public", "library")
  mediaDir* = USER_DATA_DIR / "media"
  MEDIA_DIR* = mediaDir


let 
  staticDir* = joinPath(USER_DATA_DIR, "public", "static")
  tmpDir* = getTempDir() / "volekino"
  TMP_DIR* = tmpDir
  dbPath* = joinPath(USER_DATA_DIR, "volekino.db")



var mediaDirCreated*, libraryDirCreated*, thumbnailDirCreated*, subtitleDirCreated* = false

var transmission*: TransmissionRemote


var syncing* = true
proc runSync* =
  syncing = true
  let command = getAppFilename()
  echo "syncCommand = ", command
#proc main(api=true, apache=true, transmission=false, sync=true, printDataDir=false, populateUserData=true) =
  let syncProcess = startProcess(command, args=["--syncOnly=true"], options={poEchoCmd, poParentStreams, poDaemon})

  addProcess(
    syncProcess.processId,
    proc(fd: AsyncFd): bool =
      echo "sync process exited with ", $syncProcess.peekExitCode()
      syncing = false
      true
  )


proc initTransmissionRemote* =
  transmission = newTransmissionRemote(port=9092)
