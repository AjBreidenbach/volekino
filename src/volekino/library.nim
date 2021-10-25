import globals
import os, strformat
import json
import strutils
import models, config
import models/[db_library, db_thumbnails, db_subtitles]
import ffmpeg
import asyncdispatch
import ../common/library_types

import library/shared_media
export shared_media
import mimetypes

let mimes = newMimetypes()

iterator mediaFiles: string =
  #TODO make following symlinks optional
  for file in walkDirRec(mediaDir, yieldFilter = {pcFile, pcLinkToFile}, followFilter = {pcDir, pcLinkToDir}, relative = true):
    let fullPath = mediaDir / file
    let ext = splitFile(fullPath)[2]
    let mime = mimes.getMimetype(ext)

    if mime.startsWith("video/"):
      yield fullPath

const SUBTITLE_MIMES = @["text/vtt", "application/x-subrip"]

iterator subtitleFiles(dir = ""): string =
  let mediaDir = if dir == "": mediaDir else: dir
  for file in walkDirRec(mediaDir, followFilter = {pcDir, pcLinkToDir}, relative = true):
    let fullPath = mediaDir / file
    let ext = splitFile(fullPath)[2]
    let mime = mimes.getMimetype(ext)
    
    if mime in SUBTITLE_MIMES:
      yield fullPath
  


proc syncMedia*(conf: VoleKinoConfig) =
  if not mediaDirCreated:
    #createDir mediaDir
    mediaDirCreated = true

  removeOrphanEntries(libraryDb)
  removeOrphanThumbnails(libraryDb)
  removeOrphanSubtitles(subtitlesDb)


  for mediaFile in mediaFiles():
    var entryUid = libraryDb.getEntryUid(mediaFile)
    if entryUid.len == 0:
      entryUid = libraryDb.addMediaSource(mediaFile)
      let thumbnailCreated = createThumbnail(mediaFile, entryUid)
      if not thumbnailCreated:
        discard #TODO
      
    let subtitleTracks = probeSubtitleTracks(mediaFile)
    for (uid, lang, title, index) in subtitleTracks:
       if lang == "" or lang in conf.subtitleLanguages:
          subtitlesDb.addSubtitleTrack(mediaFile, entryUid, uid, lang, title, index)

proc syncSubtitles*(conf: VoleKinoConfig, dir="") =
  for file in subtitleFiles(dir):
    #echo file
    try:
      let subtitleTracks = probeSubtitleTracks(file)
      for (uid, lang, title, index) in subtitleTracks:
        let title = file[mediaDir.high + 2..^1]
        subtitlesDb.addSubtitleToPath(file, uid, lang, title, index)
        
    except: discard


proc convertMedia*(conversionRequest: ConversionRequest): int =
  let sourceEntry = libraryDb.getEntry(conversionRequest.entryUid)
  let mediaFile = mediaDir / sourceEntry.path
  #echo "media file = ,", mediaFile
  if not fileExists(mediaFile): return -1

  let (ffmpegResult, processFuture) = ffmpegProcess(
    mediaFile,
    videoEncoding=conversionRequest.videoEncoding,
    audioEncoding=conversionRequest.audioEncoding,
    container=conversionRequest.container,
    audioTrack=conversionRequest.selectedAudioTrack,
    experimentalMode=conversionRequest.experimentalMode
  )


  proc ffmpegCallback(f: Future[int]) {.gcsafe.} =
    asyncCheck f
    let exitCode = f.read()
    if exitCode != 0:
      return

    let mediaFile = mediaFile.splitFile()[0] / ffmpegResult.filename
    let entryUid = libraryDb.addMediaSource(mediaFile)
    subtitlesDb.shareSubtitles(ownerUid=conversionRequest.entryUid, receiverUid=entryUid)
    let thumbnailsDir = publicDir / "thumbnails"

    try:
      copyFile(thumbnailsDir / conversionRequest.entryUid, thumbnailsDir / entryUid)
    except: discard
    #addToLibrary(libraryDir / ffmpegResult.filename, libraryDir, tmpDir)

    if conversionRequest.removeOriginal:
      try:
        removeFile(mediaDir / sourceEntry.path)
        libraryDb.removeEntry(sourceEntry.uid)
      except:
        echo "failed to remove file ", mediaDir / sourceEntry.path


  processFuture.addCallback(ffmpegCallback)
  

  ffmpegResult.jobId
