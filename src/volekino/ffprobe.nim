import os, osproc, json
export json
import strutils



type FFProbe = distinct JsonNode
type FFProbeSubtitles = distinct JsonNode

proc `$`(s: FFProbeSubtitles): string = $ JsonNode(s)
proc ffprobe*(filename: string, attachFilename = ""): FFProbe =
  let ffprobeResult = execCmdEx("ffprobe -of json -show_format -show_streams " & quoteShell(filename), options = { poUsePath })

  var result = parseJson ffprobeResult.output
  if attachFilename.len > 0:
    result["file"] = %attachFilename


  FFProbe result


let VIDEO = %"video"
let AUDIO = %"audio"
let SUB = %"subtitle"

proc videoStreamType*(f: FFProbe): string =
  let node = JsonNode(f)
  let streams = node["streams"].getElems()

  for stream in streams:
    if stream["codec_type"] == VIDEO: return stream["codec_name"].getStr()

proc duration*(f: FFProbe): int =
  let node = JsonNode(f)
  int parseFloat(node["format"]["duration"].getStr())
  
proc audioStreamType*(f: FFProbe): string =
  let node = JsonNode(f)
  let streams = node["streams"].getElems()

  for stream in streams:
    if stream["codec_type"] == AUDIO: return stream["codec_name"].getStr()


proc subtitles*(f: FFProbe): seq[FFProbeSubtitles] =
  let node = JsonNode(f)
  let streams = node["streams"].getElems()
  for stream in streams:
    if stream["codec_type"] == SUB:
      result.add FFProbeSubtitles(stream)


proc index*(sub: FFProbeSubtitles): int =
  let node = JsonNode(sub)
  node["index"].getInt()
  
proc lang*(sub: FFProbeSubtitles): string =
  let node = JsonNode(sub)
  node{"tags", "language"}.getStr()

proc title*(sub: FFProbeSubtitles): string =
  let node = JsonNode(sub)
  node{"tags", "title"}.getStr()

when isMainModule:
  import strformat
  let probe = ffprobe("/home/andrew/sambashare/Disenchantment.S01E11.720p.WEB.X264-METCON[ettv]/Disenchantment.S01E11.720p.WEB.X264-METCON[ettv].mkv")
  #echo JsonNode(probe)
  echo probe.subtitleTracks

