{.emit: slurp("../vendor/mithril.js").}
import mithril
#import asyncjs
import mithril/common_selectors
import client/[jsffi, entry, convert, progress]
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
    echo "view"
          

      
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
    library = (await mrequest("/api/library")).to(seq[Entry])
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
  ready: bool

var Library = MComponent()

Library.oninit = lifecycleHook:
  let uid = mrouteparam("path")

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
    
  
Library.view = viewFn(LibraryState):
  if not state.ready: return mtext("")
  var subtitleNodes = newSeq[VNode]()
  for track in state.subtitles:
    subtitleNodes.add mtrack(
      a {label: track.title, kind: "subtitles", srclang: track.lang, src: cstring"/subtitles/" & track.uid}
    )
  mdiv(
    a {style: "margin: 0 auto"},
    mvideo(
      a { controls: true },
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
      "/progressbartest": toSelector TestProgressBar

    }
  )
#
