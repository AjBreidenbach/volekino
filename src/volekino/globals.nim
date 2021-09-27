import appdirs, os
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

proc initTransmissionRemote* =
  transmission = newTransmissionRemote(port=9092)
