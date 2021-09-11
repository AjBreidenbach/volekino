{.emit: slurp("../vendor/mithril.js").}
import mithril
#import asyncjs
import mithril/common_selectors
import client/[jsffi, entry, convert, progress, wsdispatcher, login, util]
import common/library_types


let mountPoint = document.querySelector(cstring"#mount")

type Directory = ref object of MComponent


type Search = ref object of MComponent
  currentInput: cstring

proc newSearch: Search =
  var search = Search(currentInput: "")


  search.onbeforeupdate = beforeUpdateHook:
    var query = getQuery()
    result = not query.u.to(bool)# or not query.search.to(bool)
    echo result


  let oninput = eventHandler:
    var query = getQuery()
    query.search = e.target.value
    discard jsDelete query.u
    e.redraw = false
    mrouteset(getPath() & cstring"?" & mbuildQueryString(query))

  search.view = viewFn(Search):
          

      
    var query = getQuery()

    if query.hasOwnProperty("search"):#search.to(bool):
      search.currentInput = query.search.to(cstring)
    

    mdiv(
      a {class: "directory-top"},
      mdiv(
        a {class: "search-container"},
        mimg(a {src: "/images/search.svg"}),
        minput(a {type: "search", oninput: oninput, value: search.currentInput})
      )
    )

    
  search



proc newDirectory: Directory =
  result = Directory()
  
  var library: seq[Entry]
  var requestComplete = false

  result.oninit = lifecycleHook:
    var response: JsObject
    handleErrorCodes:
      response = await mrequest("/api/library")
    echo "here"

    #if response.error.to(bool): console.log(response.error)
    library = response.to(seq[Entry])
    for entry in mitems library:
      init entry
    requestComplete = true
  

  let search = newSearch()
  result.view = viewFn(Directory):
    if not requestComplete:
      mh1("Loading library...")
    elif library.len == 0:
      mh1("Library is empty")
    else:
      mdiv(
        a {class: "library-container"},
        search,
        library
      )



type LibraryState = ref object
  entry: Entry
  subtitles: seq[SubtitleTrack]
  videoElement: JsObject
  uid: cstring
  ready: bool
  listeners: seq[(cstring, JsObject)]
  startingTime: float

var Library = MComponent()

Library.oninit = lifecycleHook:
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
    
Library.oncreate = lifecycleHook(LibraryState):
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
  
  let ts = localStorage[state.uid & cstring":duration"]
  if not ts.isUndefined():
    state.startingTime = parseFloat(ts)

  #state.listeners.add play

Library.onremove = lifecycleHook:
  for listener in state.to(LibraryState).listeners:
    removeEventListener(listener)

Library.onupdate = lifecycleHook(LibraryState):
  state.videoElement = vnode.dom.querySelector(cstring"video")
  if state.startingTime != 0:
    state.videoElement.currentTime = state.startingTime
    state.startingTime = 0
    
  
Library.view = viewFn(LibraryState):
  let onplay = eventHandler:
    let ts = state.videoElement.currentTime.to(float)
    sendEvent("play", PlayEvent(uid: state.uid, ts: ts))

  let onpause = eventHandler:
    let ts = state.videoElement.currentTime.to(float)
    sendEvent("pause", PauseEvent(uid: state.uid, ts: ts))
    
  let ontimeupdate = eventHandler:
    let ts = state.videoElement.currentTime.to(cstring)
    localStorage[state.uid & cstring":duration"] = ts
    
    
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


view(Page404):
  mh1("page not found")



var SideNav = MComponent()
SideNav.view = viewFn(MComponent):
  let query = getQuery()

  let tableView = query.hasOwnProperty(cstring"table")

  let libraryLink = cstring"/?" & mbuildQueryString(if tableView:
    discard jsDelete query.table
    query
  else:
    query.table = cstring""
    query
  )

  mnav(
    mimg(a {src: "/images/users.svg"}),
    m(mrouteLink,
      a {href: libraryLink},
      (
        if tableView:
          mimg(a {src: "/images/thumbnail-view.svg"})
        else:
          mimg(a {src: "/images/list-view.svg"})
      )
    ),
    mimg(a {src: "/images/movie-camera.svg"}),
    mimg(a {src: "/images/add.svg"}),
    mimg(a {src: "/images/settings.svg"})
  )
  

proc wrapPage(selector: MithrilSelector): MithrilSelector =
  #let sideNav = m(SideNav)
  view(wrapper):
    mchildren(
      mmain(
        m(selector)
      ),
      SideNav
    )
    


  wrapper

block:

  mroute(
    mountPoint,
    "/404",
    {
      "/": wrapPage newDirectory(),
      "/convert/:uid": wrapPage Convert,
      "/library/:path": wrapPage Library,
      "/404": wrapPage Page404,
      "/progressbartest": toSelector TestProgressBar,
      "/login": wrapPage Login,
      "/register": wrapPage Registration

    }
  )
#


