import mithril, mithril/common_selectors
import jsffi
#import entry
import ../common/library_types
import progress, store, ./globals

var Convert* = MComponent()

type ConvertState = ref object
  conversionStatistics: ConversionStatistics
  selectedContainer: cstring
  selectedVideoCodec: cstring
  selectedAudioCodec: cstring
  videoEncoders: seq[cstring]
  audioEncoders: seq[cstring]
  progress: int
  status: cstring
  error: cstring
  jobId: int
  selectedAudioTrack: int
  progressTimeout: cint
  ready: bool
  removeOriginal: bool
  experimentalMode: bool


proc populateEncodingParameters(state: ConvertState, selectedContainer: cstring): ConvertState =
  result = state
  let cs = state.conversionStatistics
  let currentVideoEncoding = cs.entry.videoEncoding
  let currentAudioEncoding = cs.entry.audioEncoding

  result.selectedVideoCodec = cstring ""
  result.selectedAudioCodec = cstring""
  
  var i = -1
  var videoEncoders = videoCodecsAvailableForContainer(selectedContainer, cs.encoders)
  i = videoEncoders.find(currentVideoEncoding)
  if i != -1:
    #videoEncoders.delete(i)
    videoEncoders.insert("copy " & cstring"(" & currentVideoEncoding & cstring")")
    result.selectedVideoCodec = cstring"copy"
  elif videoEncoders.len > 0:
    result.selectedVideoCodec = videoEncoders[0]
  else:
    discard
  
  var audioEncoders = audioCodecsAvailableForContainer(selectedContainer, cs.encoders)
  i = audioEncoders.find(currentAudioEncoding)
  if i != -1:
    audioEncoders.delete(i)
    audioEncoders.insert("copy")
    result.selectedAudioCodec = cstring"copy"
  elif audioEncoders.len > 0:
    result.selectedAudioCodec = audioEncoders[0]
  else:
    discard

  result.selectedContainer = selectedContainer
  result.videoEncoders = videoEncoders
  result.audioEncoders = audioEncoders

  result.ready = true


proc fetchStatus(jobId: int): Future[JsObject] {.async.} =
  mrequest(apiPrefix"/job-status/" & $jobId)
  
proc startProgressLoop(state: var ConvertState) =
  proc timeoutLoop {.async.}=
    let response = await fetchStatus(state.jobId)

    state.progress = response.progress.to(int)
    state.error = response.error.to(cstring)
    state.status = response.status.to(cstring)

    if response.status.to(cstring) == cstring"started":
      state.progressTimeout = setTimeout(timeoutLoop, 500)
    else: conversionDeleteJobId(state.conversionStatistics.entry.uid)

      
    
  discard timeoutLoop()



proc submitConversionRequest(state: var ConvertState) {.async.} =
  var requestPayload = ConversionRequest(
    entryUid: state.conversionStatistics.entry.uid,
    videoEncoding: state.selectedVideoCodec,
    audioEncoding: state.selectedAudioCodec,
    container: state.selectedContainer,
    removeOriginal: state.removeOriginal,
    selectedAudioTrack: state.selectedAudioTrack,
    experimentalMode: state.experimentalMode
  )
  let response = await mrequest(apiPrefix"/convert", Post, toJs requestPayload)
  if response.hasOwnProperty(cstring"jobId"):
    state.jobId = response.jobId.to(int)
    conversionSetJobId(state.conversionStatistics.entry.uid, state.jobId)


    state.startProgressLoop()

                
    
Convert.oninit = lifecycleHook(ConvertState):
  state.ready = false
  state.selectedAudioTrack = -1
  var uid = vnode.attrs.uid
  if not uid.to(bool):
    uid = toJs mrouteparam(cstring"uid")

  #state.id = id

  #state.conversionStatistics = await mrequest(cstring apiPrefix"/library/" & uid.to(cstring) & cstring"/conversion-statistics")
  let response = await mrequest(cstring apiPrefix"/library/" & uid.to(cstring) & cstring"/conversion-statistics")
  state.conversionStatistics = response.to(ConversionStatistics)

  console.log cstring"response = ", response
  console.log cstring"state = ", state

  state.jobId = conversionGetJobId(state.conversionStatistics.entry.uid)
  if state.jobId != -1:
    state.startProgressLoop()
  
  let cs = state.conversionStatistics
  
  let selectedContainer = if cs.containersAvailableWithoutCodec.len > 0:
    cs.containersAvailableWithoutCodec[0]
  elif cs.containersAvailableWithoutVideoCodec.len > 0:
    cs.containersAvailableWithoutVideoCodec[0]
  else: "mp4"


  state = populateEncodingParameters(state, selectedContainer)
 
  

Convert.view = viewFn(ConvertState):
  if not state.ready:
    return mtext("")
  var audioNodes = newSeq[VNode]()
  var videoNodes = newSeq[VNode]()

  var info = cstring ""

  for encoder in state.videoEncoders:
    let selected = state.selectedVideoCodec == encoder
    let value = toLowerCase(encoder).split(newRegExp(r"\s+"))[0]
    videoNodes.add moption(a {value: value, selected: selected}, encoder)

  if state.selectedVideoCodec.len > 0 and state.selectedVideoCodec != cstring"copy":
    info = cstring "Note: re-encoding a video stream takes substantially longer than copying into the desired container"

  for encoder in state.audioEncoders:
    let selected = state.selectedAudioCodec == encoder
    audioNodes.add moption(a {value: toLowerCase(encoder), selected: selected}, encoder)


  let onchangeContainer = eventHandler:
    state = populateEncodingParameters(state, e.target.value.to(cstring))
    

  let onchangeAudio = eventHandler:
    state.selectedAudioCodec = e.target.value.to(cstring)

  let onchangeAudioTrack = eventHandler:
    state.selectedAudioTrack = parseInt(e.target.value)

  let onchangeVideo = eventHandler:
    state.selectedVideoCodec = e.target.value.to(cstring)
  
  let initiateConversion = eventHandler:
    e.redraw = false
    discard state.submitConversionRequest()

  let ontoggleRemoveOriginal = eventHandler:
    state.removeOriginal = e.target.checked.to(bool)

  let ontoggleExperimentalMode = eventHandler:
    state.experimentalMode = e.target.checked.to(bool)

  mdiv(
    a {style: "background-color: white; padding: 1em; display: flex; flex-wrap: wrap; justify-content: space-between; align-items: flex-end"},
    mh6(a {style: "width: 100%"}, state.conversionStatistics.entry.path),
    mdiv(
      mlabel(
        "Container:",
        mselect(
          a {value: state.selectedContainer, onchange: onchangeContainer},
          moption(a {value: "mp4"}, "MP4"),
          moption(a {value: "webm"}, "WebM"),
          moption(a {value: "ogg"}, "Ogg")
        )
      ),
      mlabel(
        "Audio:",
        (
          if audioNodes.len > 0:
            mselect(
              a {onchange: onchangeAudio},
              mchildren(audioNodes)
            )
          else:
            mspan("none supported")
        )
      ),
      (
      if state.conversionStatistics.entry.audioTracks.len > 1:
        mlabel(
          "Audio track:",
          block:
            var options = newSeq[VNode]()
            for track in state.conversionStatistics.entry.audioTracks:
              options.add moption(
                a {value: track.index},
                track.title & (if track.title.len > 0: cstring"/" else: cstring"") & track.lang
              )

            mselect(
              a {onchange: onchangeAudioTrack},
              mchildren(options)
            )
        )
      else: mchildren()
      ),
      mlabel(
        "Video:",
        (
          if videoNodes.len > 0:
            mselect(
              a {onchange: onchangeVideo},
              mchildren(videoNodes)
            )
          else:
            mspan("none supported")
        )
        
      ),
      mlabel(
        "Experimental mode: ",
        minput(a {type: "checkbox", onchange: ontoggleExperimentalMode})
      )
    ),
    mdiv(
      mlabel(
        "Remove original:",
        minput(a {type: "checkbox", onchange: ontoggleRemoveOriginal})
      ),
      mbutton(
        a {style: "width: 7em; background-color: #f07e5c; filter: invert(1)", onclick: initiateConversion},
        "Convert",
        mimg(a {class: "spin", src: staticResource"/images/exchange.svg", style: "width: 1.5em"})
      )
      
    ),
    mdiv(
      a {style: "width: 100%;"},
      mtext(info)
    ),
    mdiv(
      a {style: "width: 100%;display: flex;align-items: center; margin: 1em 0 1em"},
      (
        if state.progress >= 0: mchildren(
          mspan(a {style: "line-height: 0; margin-right: 1em; font-family: monospace; margin: 0.5em"}, cstring"status: "  & state.status ),
          m(ProgressBar,
            a {value: state.progress}
          )
        )
        else:
          mdiv(
            a {style: "font-family: monospace; color: crimson; white-space: break-spaces"},
            state.error
            
          )
      )
      
    )
  )
