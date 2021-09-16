when defined(js):
  type StringImpl* = cstring
else:
  type StringImpl* = string
  
const WEBM_VIDEO_CODECS = @[StringImpl"vp8", StringImpl"vp9", StringImpl"av1"]
const MP4_VIDEO_CODECS = @[StringImpl"h264", StringImpl"av1"]
const OGG_VIDEO_CODECS = @[StringImpl"theora"]
const WEBM_AUDIO_CODECS = @[StringImpl"opus", StringImpl"vorbis"]
const MP4_AUDIO_CODECS = @[StringImpl"aac", StringImpl"mp3", #[experimental ?"opus",]# StringImpl"flac"] # chrome doesn't seem to support eac3
const OGG_AUDIO_CODECS = @[StringImpl"vorbis", StringImpl"opus", StringImpl"flac"]

type MediaContainer* = object
  supportedAudioCodecs*: seq[StringImpl]
  supportedVideoCodecs*: seq[StringImpl]
  container*: StringImpl


const WEBM = MediaContainer(container: StringImpl"webm", supportedAudioCodecs: WEBM_AUDIO_CODECS, supportedVideoCodecs: WEBM_VIDEO_CODECS)
const MP4 = MediaContainer(container: StringImpl"mp4", supportedAudioCodecs: MP4_AUDIO_CODECS, supportedVideoCodecs: MP4_VIDEO_CODECS)
const OGG = MediaContainer(container: StringImpl"ogg", supportedAudioCodecs: OGG_AUDIO_CODECS, supportedVideoCodecs: OGG_VIDEO_CODECS)


const CONTAINERS* = @[MP4, WEBM, OGG]

type ConversionRequest* = object
  entryUid*: StringImpl
  container*, videoEncoding*, audioEncoding*: StringImpl
  selectedAudioTrack*: int
  removeOriginal*: bool

type AudioTrackIdentifier* = object
  title*, lang*: StringImpl
  index*: int

type LibraryEntry* = object of RootObj
  uid*: StringImpl
  path*, videoEncoding*, audioEncoding*: StringImpl
  audioTracks*: seq[AudioTrackIdentifier]
  duration*: int
  resolution*: StringImpl
  aspectRatio*: StringImpl

type ConversionStatistics* = ref object
  entry*: LibraryEntry
  canDecodeAudio*, canDecodeVideo*: bool
  containersAvailableWithoutCodec*: seq[StringImpl]
  containersAvailableWithoutVideoCodec*: seq[StringImpl]
  #audioTracks*: seq[AudioTrackIdentifier]
  encoders*: seq[StringImpl]
  #resolution*: StringImpl
  #aspectRatio*: StringImpl


proc audioCodecsAvailableForContainer*(this: StringImpl, encoders: seq[StringImpl]): seq[StringImpl] =
  for container in CONTAINERS:
    if this == container.container:
      for codec in container.supportedAudioCodecs:
        if codec in encoders:
          result.add codec

      
proc videoCodecsAvailableForContainer*(this: StringImpl, encoders: seq[StringImpl]): seq[StringImpl] =
  for container in CONTAINERS:
    if this == container.container:
      for codec in container.supportedVideoCodecs:
        if codec in encoders:
          result.add codec
 


type SubtitleTrack* = object of RootObj
  uid*, lang*, title*: StringImpl
  #entryId: int16
