import os, osproc
import strformat
import sequtils
import strutils
import re
import streams
import asyncdispatch
import models/db_library
import models/db_jobs
import models
import ../common/library_types
export library_types.ConversionStatistics


type Codec = object
  codec: string
  encoding: bool
  decoding: bool


var videoCodecs = newSeq[Codec]()
var audioCodecs = newSeq[Codec]()
var encoders = newSeq[string]()


proc canEncode(codec: string): bool =
  for c in videoCodecs:
    if c.codec == codec:
      return c.encoding

  for c in audioCodecs:
    if c.codec == codec:
      return c.encoding
    

proc canDecode(codec: string): bool =
  for c in videoCodecs:
    if c.codec == codec:
      return c.decoding

  for c in audioCodecs:
    if c.codec == codec:
      return c.decoding
 

proc containersAvailable(videoEncoding, audioEncoding: string): seq[string] =
  for container in CONTAINERS:
    if audioEncoding in container.supportedAudioCodecs and videoEncoding in container.supportedVideoCodecs:
      result.add(container.container)


proc containersAvailableWithAudioConversion(videoEncoding, audioEncoding: string): seq[string] =
  if not audioEncoding.canDecode:
    return containersAvailable(audioEncoding, videoEncoding)
  
  for container in CONTAINERS:
    if videoEncoding in container.supportedVideoCodecs:
      if audioEncoding in container.supportedAudioCodecs:
        result.add(container.container)
        continue

      for audioEncodingOption in container.supportedAudioCodecs:
        if audioEncodingOption.canEncode:
          result.add(container.container)
          break


proc conversionStatistics*(le: LibraryEntry): ConversionStatistics =
  result = ConversionStatistics()
  result.entry = le
  result.canDecodeAudio = le.audioEncoding.canDecode
  result.canDecodeVideo = le.videoEncoding.canDecode
  result.containersAvailableWithoutCodec = containersAvailable(le.videoEncoding, le.audioEncoding)
  result.containersAvailableWithoutVideoCodec = containersAvailableWithAudioConversion(le.videoEncoding, le.audioEncoding)
  result.encoders = encoders

var ffmpeg = findExe("ffmpeg")
if ffmpeg == "":
  ffmpeg = findExe("aconv")


proc populateCodecLists =
  let codecs = execCmdEx(&"{ffmpeg} -codecs", {poUsePath})
  for line in codecs.output.splitLines:
    if line.len < 4: continue

    let decodingSupported = line[1] == 'D'
    let encodingSupported = line[2] == 'E'

    if decodingSupported or encodingSupported:
      #var s = newSeq[Codec](0)

      let codec = line.splitWhitespace()[1]
      
      if line[3] == 'A':
        audioCodecs.add(Codec(encoding: encodingSupported, decoding: decodingSupported, codec: codec))
      elif line[3] == 'V':
        videoCodecs.add(Codec(encoding: encodingSupported, decoding: decodingSupported, codec: codec))
        
    #echo line
  
proc parseFfmpegTimeNotation(s: string): int =
  let timeComponents = s[0..s.high-3].split(':')
  parseInt(timeComponents[0]) * 3600 + parseInt(timeComponents[1]) * 60 + parseInt(timeComponents[2])

let durationRegex = re"Duration:\s?(\d{2}:\d{2}:\d{2}\.\d{2})"
proc ffmpegOutputDuration(output: string): int =
  let bounds = output.findBounds(durationRegex)
  echo output, bounds
  if bounds[0] == -1: -1
  else: parseFfmpegTimeNotation(output[bounds[1] - 10..bounds[1]])

  
let timeRegex = re"time\=(\d{2}:\d{2}:\d{2}\.\d{2})"
proc ffmpegCurrentTime(output: string): int =
  let bounds = output.findBounds(timeRegex)
  if bounds[0] == -1: -1
  else:
    parseFfmpegTimeNotation(output[bounds[1] - 10..bounds[1]])



populateCodecLists()
for container in CONTAINERS:
  for videoCodec in container.supportedVideoCodecs:
    if videoCodec.canEncode:
      encoders.add videoCodec
  for audioCodec in container.supportedAudioCodecs:
    if audioCodec.canEncode:
      encoders.add audioCodec

encoders = encoders.deduplicate()


proc decideBestContainer(videoInputEncoding, audioInputEncoding, videoOutputEncoding, audioOutputEncoding: string): string =
  let videoEncoding = if videoOutputEncoding == "copy": videoInputEncoding else: videoOutputEncoding
  let audioEncoding = if audioOutputEncoding == "copy": audioInputEncoding else: audioOutputEncoding

  for container in CONTAINERS:
    if not (videoEncoding in container.supportedVideoCodecs):
      continue

    if not (audioEncoding in container.supportedAudioCodecs):
      continue

    return container.container


proc ffmpegProcessInner(inputFile: string, videoEncoding="copy", audioEncoding="copy", outputFile: string, jobId: int, audioTrack=(-1), experimentalMode=false): Future[int] {.async.} =
  result = -1
 
  var args = @["-i", inputFile, "-c:v", videoEncoding, "-c:a", audioEncoding]
  
  if audioTrack != -1:
    args.add ["-map", &"0:{audioTrack}", "-map", "0:v:0"]


  args.add ["-y", "-stats"]#, outputFile]
  if experimentalMode:
    args.add ["-strict", "-2"]

  args.add outputFile

  echo args
  let process = startProcess(ffmpeg, args=args, options = {})

  var ffmpegErrStream = process.errorStream

  var duration = -1
  var currentTime = -1

  #addProcess(process.processID, proc(fd: AsyncFD): bool =
  #  jobsDb.updateJob(jobId, 100, "complete")
  #)
  var errorBuffer = ""

  while process.peekExitCode == -1:
    var line = ""
    try:
      line = ffmpegErrStream.readLine
    except:
      await sleepAsync(10)
      continue
    errorBuffer.add line
    errorBuffer.add '\n'
    #echo "stdErr: ", line
    if duration == -1:
      duration = ffmpegOutputDuration(line)
    elif currentTime == -1:
      currentTime = ffmpegCurrentTime(line)
    else:
      jobsDb.updateJob(jobId, 100 * currentTime div duration)
      currentTime = ffmpegCurrentTime(line)

      await sleepAsync(500)


  let exitCode = waitForExit(process, timeout=1000)
  result = exitCode

  if exitCode == 0:
    jobsDb.updateJob(jobId, 100, "complete")
  else:
    #let output = process.outputStream.readAll
    jobsDb.errorJob(jobId, status=("exitCode: " & $exitCode), error=errorBuffer)
    #echo output#process.outputStream.readAll
  
  process.close

type FFMPEGProcessResult* = object
  jobId*: int
  filename*: string

#TODO move arg builder here
proc ffmpegProcess*(inputFile: string, videoEncoding="copy", audioEncoding="copy", container="", inputVideoEncoding="", inputAudioEncoding="", audioTrack=(-1), experimentalMode=false): (FFMPEGProcessResult, Future[int]) =
  let (outputDir, inputBasename, inputExt) = splitFile(inputFile)

  if container == "" and ((inputVideoEncoding == "" and videoEncoding == "copy") or (inputAudioEncoding == "" and audioEncoding == "copy")):
    raise newException(Exception, "Must provide a container type as it's possible none may be inferred")
  
  
  if container.len == 0:
    let container = decideBestContainer(inputVideoEncoding, inputAudioEncoding, videoEncoding, audioEncoding)
    #NOTE: DON'T FORGET TO ADD NEW PARAMS HERE
    return ffmpegProcess(inputFile, videoEncoding, audioEncoding, container, audioTrack=audioTrack, experimentalMode=experimentalMode)

  let outputFilename = (
    if container == inputExt[1..^1]:
      inputBasename & &"({videoEncoding}-{audioEncoding})" &  inputExt
    else:
      inputBasename & '.' & container
  )

  let outputDestination = outputDir / outputFilename


  let jobId = jobsDb.createJob()

  result[0] = FFMPEGProcessResult(jobId: jobId, filename: outputFilename)

  result[1] = ffmpegProcessInner(inputFile, videoEncoding, audioEncoding, outputDestination, jobId, audioTrack=audioTrack, experimentalMode=experimentalMode)


#[
proc ffmpegProcessChecked*(inputFile: string, videoEncoding="copy", audioEncoding="copy", container="", inputVideoEncoding="", inputAudioEncoding=""): FFMPEGProcessResult =
  let inner = ffmpegProcess(inputFile, videoEncoding, audioEncoding, container, inputVideoEncoding, inputAudioEncoding)
  result = inner[0]
  asyncCheck inner[1]
]#

when isMainModule:
  initTestDb()
  waitFor ffmpegProcess("/home/andrew/.local/share/VoleKino/public/library/Disenchantment.S01.COMPLETE.WEB.x264-STRiFE[TGx]/disenchantment.s01e01.web.x264-strife.mp4", "copy", "aac", "mp4")[1]
  
