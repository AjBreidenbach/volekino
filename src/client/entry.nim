import mithril, mithril/common_selectors
import ./jsffi, ./store, ./globals
import algorithm
import ../common/library_types
import strformat

type Entry* = ref object of LibraryEntry
  #id*: int16
  #path*, videoEncoding*, audioEncoding*: cstring
  splits*: seq[cstring]
  containingDirectory*: cstring
  pathTail*, pathHead*: cstring

proc initPathTail(e: Entry): cstring =
  e.splits[e.splits.high]
  

proc initPathHead(e: Entry): cstring =
  e.splits[0..<e.splits.high].join(cstring"/")


proc init*(e: var Entry) =
  e.splits = e.path.split(cstring "/")
  e.pathTail = initPathTail(e)
  e.pathHead = initPathHead(e)
  var sliceEnd = e.path.rfind('/')
  if sliceEnd == -1:
    sliceEnd = 0
  e.containingDirectory = e.path.slice(0, sliceEnd)


var selected: JsSet = newJsSet()
var deleted: JsSet = newJsSet()

proc displayDuration(dur: int): string =
  let
    h = dur div 3600
    m = (dur mod 3600) div 60  
    s = dur mod 60

  if h != 0:
    if h < 10: result.add '0'
    result.add $h
    result.add ':'

  if h == 0 and m == 0:
    result.add "0:"
  else:
    if h != 0 and m < 10:
      result.add '0'

    result.add $m
    result.add ':'


  if s < 10:
    result.add '0'

  result.add $s
  
var image404 = newJsSet()

let onSourcelessImage = eventHandler:
  image404.incl e.target.src.to(cstring)
  e.target.src = staticResource"/images/film-frames.svg"
   

proc toThumbnailView(entry: Entry, class, imageSource, pathToVideo, directoryPath: cstring): VNode =

  mdiv(
    a {class: class},
    m(mrouteLink, a {href: pathToVideo, class: "nodecorate"},
    mdiv(
      a {class: "entry-thumbnail-container"},
        mimg(a {loading: "lazy", class: "thumbnail-large", src: imageSource, error: (if imageSource.len > 0: onSourcelessImage else: nil)}),
        mdiv(
          a {class: "title"},
          entry.pathTail#,
          #[(
            if entry.pathHead.len > 0:
              m(mrouteLink,
                a {href: directoryPath},
                mimg(a {src:"/images/open-folder.svg"})
              )
            else:
              mchildren()
          )
          ]#
        ),
        mdiv(
          a {class: "video-duration"},
          block:
            let currentTime = getCurrentTime(entry.uid).floor
            if currentTime != 0:
              displayDuration(currentTime) & " / " & displayDuration(entry.duration)
            else: displayDuration(entry.duration)
        ),
        block progressBar:
          let currentTime = getCurrentTime(entry.uid)
          if currentTime != 0.0:
            let progress = $((100.0 / float(entry.duration) * currentTime).floor) & '%'
            mdiv(a {class: "video-progress", style: &"width: {progress};"})

            
          else: mtext()

      )
    )#[,
    mdiv(
      a {class: "entry-info"},
      mdiv(
        a {class: "directory-path"},
        m(mrouteLink, a {href: directoryPath}, entry.pathHead),
        mhr(),
      )#,
      #m(mrouteLink, a {href: pathToVideo}, entry.pathTail)
    )
    ]#
  )


proc toTableRowView(entry: Entry, class, imageSource, pathToVideo, directoryPath: cstring): VNode =
  let toggleSelect = eventHandler:
    #e.redraw = false
    if entry.uid in selected:
      selected.excl entry.uid
    else:
      selected.incl entry.uid

    #discard mrequest(cstring"/api/library/" & toJs(entry.id).to(cstring), cstring"delete")

  mtr(

    a {class: class},
    mtd(
      mimg(a {src: (if entry.uid in selected: staticResource"/images/enabled.svg" else: staticResource"/images/disabled.svg"), style: "    width: 2em; padding: 0.5em; box-sizing: border-box;", onclick: toggleSelect})
    ),
    mtd(
      m(mrouteLink, a {href: pathToVideo, class: "flex-cell"},
        mimg(a {loading: "lazy", class: "thumbnail-tiny", src: imageSource, error: (if imageSource.len > 0: onSourcelessImage else: nil)}),
        entry.pathTail
      )
    ),
    (
      mtd(
        if entry.pathHead.len > 0: m(mrouteLink, a {href: directoryPath, class: "flex-cell"},
          mimg(a {src: staticResource"/images/open-folder.svg"}),
          entry.pathHead
        )
        else: "")
    ),
    mtd(
      m(mrouteLink, a {href: (preserveQuery("/convert/" & toJs(entry.uid).to(cstring))), class: "flex-cell"},
        mimg(a {src: staticResource"/images/exchange.svg", style: "width: 1.5em; padding:0"}),
        entry.videoEncoding & cstring"/" & entry.audioEncoding
      )
    )
    
  )

proc subdirectoryContainer*(children: var seq[VNode]): VNode =
  if children.len == 0: return mchildren()
  result = (
    mdiv(
      a {style: "overflow-x: auto; overflow-y: hidden; position:relative; height: 200px;"},
      mdiv(
        a {style: "display: flex; position: absolute;"},
        children
      )
    )
  )
  children.setLen(0)



converter toVNode*(entries: seq[Entry]): VNode =
  var entryNodes = newSeq[VNode]()
  #let entries = entries.sortedByIt(it.path)

  var searchPath = cstring""
  let query = getQuery()
  if query.search.to(bool):
    searchPath = query.search.to(cstring).toLowerCase()
      

  let currentPath = getPath() & cstring"?"

  #TODO
  let shouldDisplayTable = query.hasOwnProperty(cstring"table")
    
  var containingDirectory = cstring""
  var flushContainerDirectory = false
  var directoryChildren = newSeq[VNode]()

  var hiddenCount = 0
  for entry in entries:
    if entry.uid in deleted: continue
    var imageSource = staticResource"/thumbnails/" & entry.uid.toJs.to(cstring)
    if imageSource in image404: imageSource = cstring""
    let pathToVideo = "/library/" & entry.uid#encodeURI(entry.path).replace(newRegExp(r"\/", "g"), "%2F")

    var class = "entry"
    

    if searchPath.len > 2 and not (searchPath in entry.path.toLowerCase()):
      class &= " hidden"
      inc hiddenCount

       
    var q = clone query
    q.search = entry.pathHead
    q.u = true

    let directoryPath = currentPath & mbuildQueryString(q)
    
    if (not shouldDisplayTable) and isFalsey query.search:
      if entry.containingDirectory != containingDirectory:
        #flushContainerDirectory = true

        entryNodes.add subdirectoryContainer(directoryChildren)

        if entry.containingDirectory.len > 0:
          entryNodes.add(
            m(mrouteLink,
              a {href: directoryPath},
              mh2(
                a {style: "display: flex; align-items: center; margin: 1em 1em 0 1em; font-size: 1.3em; font-weight: 400;"},
                entry.containingDirectory,
                mimg(a {src: staticResource"/images/open-folder.svg"})
              )
            )
          )
        else: entryNodes.add mbr()
        containingDirectory = entry.containingDirectory
     
      
    entryNodes.add (
      if shouldDisplayTable:
        toTableRowView(
          entry, class, imageSource, pathToVideo, directoryPath
        )
      elif entry.containingDirectory.len > 0 and isFalsey query.search:
        directoryChildren.add toThumbnailView(
          entry, class, imageSource, pathToVideo, directoryPath
        )
        nil
      else:
        toThumbnailView(
          entry, class, imageSource, pathToVideo, directoryPath
        )

    )
  if directoryChildren.len > 0:
    entryNodes.add subdirectoryContainer(directoryChildren)

  let entryListStyle = if shouldDisplayTable: "" else: "justify-content: space-between"

  let deleteSelected = eventHandler:
    for uid in selected:
      discard mrequest(apiPrefix"library/" & toJs(uid).to(cstring), cstring"delete")
    deleted.incl selected
    selected = newJsSet()

  let clearSelected = eventHandler:
    selected = newJsSet()

  mdiv(
    a {class: "entry-list spacer", style: entryListStyle},
    (
      if shouldDisplayTable:
        mtable(
          mthead(
            mtr(
              a {style: "height: 3em"},
              mchildren(
                mth(
                  a {colspan: 2, style: "position: relative"},
                  (
                    if selected.len > 0:
                      mdiv(
                        a {style: "font-size: 0.5em; position: absolute;", class: "table-view-context-menu"},
                        mimg(a {src: staticResource"/images/cancel.svg", style: "width: 2.5em", onclick: clearSelected}),
                        mimg(a {class: "disabled", src: staticResource"/images/exchange.svg", style: "width: 2.5em"}),
                        mimg(a {src: staticResource"/images/delete.svg", style: "width: 2.5em", onclick: deleteSelected})
                      )
                    else: mchildren()
                  ),
                  "Media"
                ),
                mth("Directory"),
                mth(mspan(a {class: "flex-cell"}, "Encoding"))
              )
            )
            #[
            mtr(
              a {style: "height: 3em"},
              if selected.len == 0:
                mchildren(
                  mth(""),
                  mth("Media"),
                  mth("Directory"),
                  mth("Encoding")
                )
              else:
                mth(
                  a {colspan: 4},
                  mdiv(
                    a {class: "table-view-context-menu"},
                    mimg(a {src: staticResource"/images/cancel.svg", style: "width: 2.5em", onclick: clearSelected}),
                    mimg(a {class: "disabled", src: staticResource"/images/exchange.svg", style: "width: 2.5em"}),
                    mimg(a {src: staticResource"/images/delete.svg", style: "width: 2.5em", onclick: deleteSelected})
                  )
                )
            )
            ]#
          ),
          mtbody(
            entryNodes
          )
        )
      else:
        mchildren(
          (
            if hiddenCount == entries.len:
              mchildren()
            else:
              mdiv(a {style: "width: 100%; height: 1em;"})
          ),
          mchildren(entryNodes)
        )
    )
  )


