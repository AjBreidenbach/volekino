import mithril, mithril/common_selectors, ./jsffi
import progress, store, ./globals, ./folder_select, ./util
import ../common/library_types
import strformat, sequtils
import wsdispatcher

var ignoreJobs = newJsSet()

var DownloadProgressIndicator, DownloadProgressPopupView*, DownloadProgressDefaultView, AddMediaView*, AddedMediaList = MComponent()

var 
  ongoingDownloads: seq[Download]
  couldNotFetch = false
  timeout = cint -1
  timeoutDuration = cint 1000

#TODO we can avoid redraws if the result hasn't changed
proc refreshDownloads() {.async.} =
  try:
    let newDownloads = (await mrequest(apiPrefix"downloads", background=true)).to(seq[Download])
    if newDownloads == ongoingDownloads:
      timeoutDuration += 500
    else:
      timeoutDuration = 1000
      ongoingDownloads = newDownloads
      mredraw()
    #console.log(cstring"ongoingDownloads: ", ongoingDownloads)
  except:
    couldNotFetch = true
    timeout = -1



proc loop: Future[void] {.async.} =
  if couldNotFetch:
    return

  await refreshDownloads()
  timeout = setTimeout(timeoutDuration,
    AsyncTimeoutFunction loop
  )

discard loop()


let popupMinimizeHandler = eventHandler:
  hidePopup()

let popupShowHandler = eventHandler:
  showPopup()

DownloadProgressPopupView.view = viewFn:
  #echo "downloadProgressPopup"
  if ongoingDownloads.len == 0 or getPath() == cstring"/add":
    popupEnabled = false
    return mchildren()
  
  popupEnabled = popupEnabledDefault()
  mdiv(
    a {class: if popupEnabled: "downloads-popup" else: "downloads-popup collapsed"},
    mdiv(
      a {style: "position: absolute; left: 0; width: 100%; top: 0; background-color: #8ed9ea; height: 1.75em; font-weight: bold; text-align: left; display: flex; align-items: center; padding: 0 0.5em; box-sizing: border-box;"},
      block:
        if popupEnabled:
          mchildren(
            mimg(a {src: staticResource"/images/minus.svg", style:"width: 2em; right: 0; position: absolute", onclick: popupMinimizeHandler}),
            "Downloads"
          )
        else:
          mimg(a {src: staticResource"/images/chevron.svg", style: "width: 2em; position: absolute; left: 0;", onclick: popupShowHandler})
          
    ),

    if popupEnabled: m(DownloadProgressDefaultView)
    else: mchildren()
  )

DownloadProgressDefaultView.view = viewFn:
  mchildren(
    block:
      var downloadNodes = newSeq[VNode]()
      for download in ongoingDownloads:
        downloadNodes.add m(DownloadProgressIndicator, a {
          resourceName: download.resourceName,
          progress: download.progress
        })
      downloadNodes

  )


DownloadProgressIndicator.view = viewFn:
  var 
    resourceName = vnode.attrs.resourceName.to(cstring)
    progress = vnode.attrs.progress.to(cint)
    width = vnode.attrs.width.to(cstring)

  if isFalsey resourceName: resourceName = cstring""
  if resourceName in ignoreJobs:
    return
  if isFalsey progress: progress = 0
  if isFalsey width: width = cstring"600px"

  let ignoreDownload = eventHandler:
    ignoreJobs.incl resourceName

  let resourceNameEl = mspan(a {style: "white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 260px; display: inline-block; }"}, resourceName)

  mdiv(
    a {class: "download-progress-indicator", style: &"width: min(100%, {width})"},
    (
     if progress == 100:
      m(mrouteLink,
        a {href: cstring"/?search=" & encodeUri(resourceName)},
        resourceNameEl
      )
    else: resourceNameEl
    ),
    mdiv(
      a {style: "display: flex; align-items: center;"},
      m(ProgressBar, a {value: progress, width: "260px"}),
      #mimg(a {src: "/images/cancel.svg", style: "width: 1em;", onclick: ignoreDownload})

    )
  )
  
type AddedMediaListState = ref object
  list: seq[AddedMediaEntry]
  listener: tuple[event: cstring, handler: JsObject]

proc populate(state: var AddedMediaListState) {.async.} =
  state.list = (await mrequest(apiPrefix"shared-media")).to(seq[AddedMediaEntry])
  state.list.sort do (a, b: AddedMediaEntry) -> int:
    a.kind - b.kind

proc remove(state: var AddedMediaListState, media: cstring) {.async.} =
  discard (await mrequest(apiPrefix("shared-media/" & encodePath(media)), Delete, background=true))
  await state.populate()

  
  
AddedMediaList.oninit = lifecycleHook(AddedMediaListState):
    
  state.list = @[]
  discard state.populate()
  # I don't think this assignment works
  state.listener = (
    addEventListener(cstring"updatemedialist", JsObject) do:
    discard state.populate()
  )

#AddedMediaList.oncreate = lifecycleHook(AddedMediaListState):
  
#  console.log(cstring"oncreate", state)

#[
AddedMediaList.onremove = lifecycleHook(AddedMediaListState):
  console.log(state)
  removeEventListener(state.listener)
]#

AddedMediaList.view = viewFn(AddedMediaListState):
  
  proc removeMediaHandler(media: cstring): EventHandler =
    return eventHandler:
      discard state.remove(media)
      e.redraw = false
  if state.list.len > 0:
    result = mdiv(
      mh4("Added media"),
      mul(
        a {style: "list-style-type: none;"},
          state.list.mapIt(
            block:
              var remove: EventHandler
              closureScope:
                let media = it.name
                remove = removeMediaHandler(media)
                                  
              mli(
                a {style: "display: flex; align-items: center; margin: 0.5em;"},
                mimg(a {onclick: remove, style: "cursor: pointer; width: 1em; padding: 0.25em;", src: staticResource"/images/cancel.svg"}),
                case it.kind
                of MediaMediaEntry:
                  mimg(a {style: "width: 1em;", src: staticResource"/images/media.svg"})
                of DirMediaEntry:
                  mimg(a {style: "width: 1em;", src: staticResource"/images/open-folder.svg"})
                of TorrentEntry:
                  mimg(a {style: "width: 1em; padding: 0.25em;", src: staticResource"/images/torrent.svg"})
                else: mimg()
                ,
                it.name
              )
          )
      )
    )

AddMediaView.view = viewFn:
  let addDownload = eventHandlerAsync:
    let input = vnode.dom.querySelector("input[type='url']")
    let request = DownloadRequest(url: input.value.to(cstring))
    discard (await mrequest(apiPrefix"downloads", Post, toJs request))

    if timeout != -1:
      clearTimeout(timeout)
    discard loop()

  mdiv(
    a {style: "margin: 3em auto; width: min(100%, 600px)"} ,
    m(FolderSelectForm),
    mcenter(a {style: "margin: 2em; display:flex;"}, mhr(a {style: "flex-grow: 5; opacity: 0.5;"}), mspan(a {style: "flex-grow: 1;"}, "or"), mhr(a {style: "flex-grow: 5; opacity: 0.5;"})),
    mh5(a {style:"margin: 1em 0 0 0; text-align: center"}, "Enter a url to download"),
    mform(
      mlabel(
        #"URL",
        minput(a {placeholder: "URL ...", style:"width: 100%", type:"url"})
      ),
      mcenter(
        mh6(a {style:"margin: 0.5em 0 0.75em 0"}, "Magnet urls and http(s) urls are supported"),
        minput(a {style:"width:200px;max-width:unset;", type:"submit", value:"Add", onclick:addDownload})
      )
      
    ),
    mdiv(a {style: "height: 75px"}),
    (
      if ongoingDownloads.len > 0:
        mchildren(
          mh6(a {style: "margin: 0.75em 0"}, "Downloads"),
          DownloadProgressDefaultView
        )
      else: nil
    ),
    
    m(AddedMediaList)
    
   #m(DownloadProgressIndicator, a {resourceName: "Archer Season 4", progress: "50"})
  )

