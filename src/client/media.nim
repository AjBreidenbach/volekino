import mithril, mithril/common_selectors
import ./entry, ./jsffi, ./wsdispatcher, ./store
import ../common/library_types
type MediaState = ref object
  entry: Entry
  subtitles: seq[SubtitleTrack]
  videoElement: JsObject
  uid: cstring
  ready: bool
  listeners: seq[(cstring, JsObject)]
  startingTime: float

var Media* = MComponent()

Media.oninit = lifecycleHook:
  let uid = mrouteparam("path")
  state.uid = uid
  state.startingTime = 0.0

  var 
    entryPromise = mrequest("/api/library/" & uid)
    subtitlesPromise = mrequest("/api/library/" & uid & "/subtitles")


  var entryFulfilled, subtitlesFulfilled = false
  entryPromise.addCallback do(o: JsObject):
    state.entry = o
    if subtitlesFulfilled:
      state.ready = true
    entryFulfilled = true

  subtitlesPromise.addCallback do(o: JsObject):
    state.subtitles = o
    if entryFulfilled:
      state.ready = true
    subtitlesFulfilled = true
    
Media.oncreate = lifecycleHook(MediaState):
  state.listeners = @[
    addEventListener(cstring"play", PlayEvent) do:
      if detail.uid == state.uid:
        state.videoElement.currentTime = detail.ts
        state.videoElement.play()
    ,
    addEventListener(cstring"pause", PauseEvent) do:
      if detail.uid == state.uid:
        state.videoElement.currentTime = detail.ts
        state.videoElement.pause()
  ]
  
  let ts = localStorage[state.uid & cstring":currentTime"]
  if not ts.isUndefined():
    state.startingTime = parseFloat(ts)

  #state.listeners.add play

Media.onremove = lifecycleHook:
  for listener in state.to(MediaState).listeners:
    removeEventListener(listener)

Media.onupdate = lifecycleHook(MediaState):
  state.videoElement = vnode.dom.querySelector(cstring"video")
  if state.startingTime != 0 and not state.videoElement.isNil:
    state.videoElement.currentTime = state.startingTime
    state.startingTime = 0
    
  
Media.view = viewFn(MediaState):
  let onplay = eventHandler:
    let ts = state.videoElement.currentTime.to(float)
    sendEvent("play", PlayEvent(uid: state.uid, ts: ts))

  let onpause = eventHandler:
    let ts = state.videoElement.currentTime.to(float)
    sendEvent("pause", PauseEvent(uid: state.uid, ts: ts))
    
  let ontimeupdate = eventHandler:
    #let ts = state.videoElement.currentTime.to(cstring)
    setCurrentTime(state.uid, state.videoElement.currentTime)
    #localStorage[state.uid & cstring":currentTime"] = ts
    
    
  if not state.ready: return mtext("")
  var subtitleNodes = newSeq[VNode]()
  for track in state.subtitles:
    subtitleNodes.add mtrack(
      a {label: track.title, kind: "subtitles", srclang: track.lang, src: cstring"/subtitles/" & track.uid}
    )
  mdiv(
    a {style: "margin: 0 auto"},
    mvideo(
      a { controls: true , onplay: onplay, onpause: onpause, ontimeupdate: ontimeupdate},
      msource(
        a {
          src: (cstring"/library/" & mrouteparam("path")),
          type: cstring"video/" & state.entry.path.split(cstring".")[^1]
        }
      ),
      mchildren(subtitleNodes)

    )
  )


