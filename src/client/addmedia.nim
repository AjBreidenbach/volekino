import mithril, mithril/common_selectors, ./jsffi
import progress, store
import ../common/library_types


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
      a {style: "text-align: right; position: sticky; top: -2em"},
      block:
        if shouldHidePopup():
          mimg(a {src:"/images/chevron.svg", style: "width: 2em", onclick: popupShowHandler})
        else:
          mimg(a {src:"/images/minus.svg", style:"width: 2em", onclick: popupMinimizeHandler})
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

  mdiv(
    a {class: "download-progress-indicator", style: cstring"width: " & width},
    mspan(a {style: "word-break: break-word;"}, resourceName),
    mdiv(
      a {style: "display: flex; align-items: center;"},
      m(ProgressBar, a {value: progress}),
      mimg(a {src: "/images/cancel.svg", style: "width: 1em;", onclick: ignoreDownload})

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
    a {style: "width: 600px"},
    mcenter(
      mh5("Enter a url to download"),
      mh6("Magnet urls and http(s) urls are supported")
    ),
    mform(
      mlabel(
        "URL",
        minput(a {style:"width: 100%", type:"url"})
      ),
      minput(a {type:"submit", value:"Add", onclick:addDownload})
      
    ),
    DownloadProgressDefaultView
    
    #m(DownloadProgressIndicator, a {resourceName: "Archer Season 4", progress: "50"})
  )

