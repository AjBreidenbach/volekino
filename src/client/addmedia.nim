import mithril, mithril/common_selectors, ./jsffi
import progress, store
import ../common/library_types
import strformat

var ignoreJobs = newJsSet()

var DownloadProgressIndicator, DownloadProgressPopupView*, DownloadProgressDefaultView, AddMediaView* = MComponent()

var 
  ongoingDownloads: seq[Download]
  couldNotFetch = false
  timeout = cint -1
  timeoutDuration = cint 1000

#TODO we can avoid redraws if the result hasn't changed
proc refreshDownloads() {.async.} =
  try:
    let newDownloads = (await mrequest("/api/downloads", background=true)).to(seq[Download])
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
  
  popupEnabled = true
  mdiv(
    a {class: if shouldHidePopup(): "downloads-popup collapsed" else: "downloads-popup"},
    mdiv(
      a {style: "position: absolute; left: 0; width: 100%; top: 0; background-color: #8ed9ea; height: 1.75em; font-weight: bold; text-align: left; display: flex; align-items: center; padding: 0 0.5em; box-sizing: border-box;"},
      block:
        if shouldHidePopup():
          mimg(a {src:"/images/chevron.svg", style: "width: 2em; position: absolute; left: 0;", onclick: popupShowHandler})
        else:
          mchildren(
            mimg(a {src:"/images/minus.svg", style:"width: 2em; right: 0; position: absolute", onclick: popupMinimizeHandler}),
            "Downloads"
          )
    ),

    if shouldHidePopup(): mchildren()
    else: DownloadProgressDefaultView
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
  

AddMediaView.view = viewFn:
  let addDownload = eventHandlerAsync:
    let input = vnode.dom.querySelector("input[type='url']")
    let request = DownloadRequest(url: input.value.to(cstring))
    console.log (await mrequest("/api/downloads", Post, toJs request))
    if timeout != -1:
      clearTimeout(timeout)
    discard loop()

  mdiv(
    a {style: "margin: 3em auto; width: min(100%, 600px)"} ,
    mh5(a {style:"margin: 1em 0 0 0; text-align: center"}, "Enter a url to download"),
    mform(
      mlabel(
        #"URL",
        minput(a {placeholder: "URL ...", style:"width: 100%", type:"url"})
      ),
      mcenter(
        mh6(a {style:"margin: 0.5em 0 0.75em 0"}, "Magnet urls and http(s) urls are supported"),
        minput(a {style:"width:200px", type:"submit", value:"Add", onclick:addDownload})
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
    )
    
    #m(DownloadProgressIndicator, a {resourceName: "Archer Season 4", progress: "50"})
  )

