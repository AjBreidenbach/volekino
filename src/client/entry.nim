import mithril, mithril/common_selectors
import jsffi
import algorithm
import ../common/library_types

type Entry* = ref object of LibraryEntry
  #id*: int16
  #path*, videoEncoding*, audioEncoding*: cstring
  splits*: seq[cstring]
  pathTail, pathHead: cstring

proc initPathTail(e: Entry): cstring =
  e.splits[e.splits.high]
  

proc initPathHead(e: Entry): cstring =
  e.splits[0..<e.splits.high].join(cstring"/")


proc init*(e: var Entry) =
  e.splits = e.path.split(cstring "/")
  e.pathTail = initPathTail(e)
  e.pathHead = initPathHead(e)



var selected: JsSet = newJsSet()
var deleted: JsSet = newJsSet()

proc toThumbnailView(entry: Entry, class, imageSource, pathToVideo, directoryPath: cstring): VNode =
  mdiv(
    a {class: class},
    m(mrouteLink, a {href: pathToVideo, class: "nodecorate"},
    mdiv(
      a {class: "entry-thumbnail-container"},
        mimg(a {loading: "lazy", class: "thumbnail-large", src: imageSource}),
        mdiv(
          a {class: "title"},
          entry.pathTail,
          (
            if entry.pathHead.len > 0:
              m(mrouteLink,
                a {href: directoryPath},
                mimg(a {src:"/images/open-folder.svg"})
              )
            else:
              mchildren()
          )
        )
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
      mimg(a {src: (if entry.uid in selected: "/images/circle.svg" else:"/images/hollow-circle.svg"), style: "width: 1.5em; padding: 0.25em", onclick: toggleSelect})
    ),
    mtd(
      m(mrouteLink, a {href: pathToVideo, class: "flex-cell"},
        mimg(a {class: "thumbnail-tiny", src: imageSource}),
        entry.pathTail
      )
    ),
    (
      mtd(
        if entry.pathHead.len > 0: m(mrouteLink, a {href: directoryPath, class: "flex-cell"},
          mimg(a {src: "/images/open-folder.svg"}),
          entry.pathHead
        )
        else: "")
    ),
    mtd(
      m(mrouteLink, a {href: (preserveQuery("/convert/" & toJs(entry.uid).to(cstring))), class: "flex-cell"},
        mimg(a {src: "/images/exchange.svg", style: "width: 1.5em; padding:0"}),
        entry.videoEncoding & cstring"/" & entry.audioEncoding
      )
    )
    
  )

converter toVNode*(entries: seq[Entry]): VNode =
  var entryNodes = newSeq[VNode]()
  let entries = entries.sortedByIt(it.path)

  var searchPath = cstring""
  let query = getQuery()
  if query.search.to(bool):
    searchPath = query.search.to(cstring).toLowerCase()
      

  let currentPath = getPath() & cstring"?"

  #TODO
  let shouldDisplayTable = query.hasOwnProperty(cstring"table")
    

  var hiddenCount = 0
  for entry in entries:
    if entry.uid in deleted:
      continue
    let imageSource = cstring"/thumbnails/" & entry.uid.toJs.to(cstring)
    let pathToVideo = cstring"/library/" & entry.uid#encodeURI(entry.path).replace(newRegExp(r"\/", "g"), "%2F")

    var class = "entry"
    

    if searchPath.len > 2 and not (searchPath in entry.path.toLowerCase()):
      class &= " hidden"
      inc hiddenCount
        


    var q = query
    q.search = entry.pathHead
    q.u = true

    let directoryPath = currentPath & mbuildQueryString(q)
    

    entryNodes.add (

      if shouldDisplayTable:
        toTableRowView(
          entry, class, imageSource, pathToVideo, directoryPath
        )
        
      else:
        toThumbnailView(
          entry, class, imageSource, pathToVideo, directoryPath
        )

    )

  let entryListStyle = if shouldDisplayTable: "" else: "justify-content: space-evenly"

  let deleteSelected = eventHandler:
    for uid in selected:
      discard mrequest(cstring"/api/library/" & toJs(uid).to(cstring), cstring"delete")
    deleted.incl selected
    selected = newJsSet()

  let clearSelected = eventHandler:
    selected = newJsSet()

  mdiv(
    a {class: "entry-list", style: entryListStyle},
    (
      if shouldDisplayTable:
        mtable(
          mthead(
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
                    mimg(a {src: "/images/cancel.svg", style: "width: 2.5em", onclick: clearSelected}),
                    mimg(a {src: "/images/exchange.svg", style: "width: 2.5em"}),
                    mimg(a {src: "/images/delete.svg", style: "width: 2.5em", onclick: deleteSelected})
                  )
                )
            )
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


