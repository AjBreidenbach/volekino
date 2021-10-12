import jswebsockets
import jsffi, ./globals


proc wrapDetail[T](detail: T): JsObject =
  result = newJsObject()

  result.detail = toJs detail

proc newCustomEvent(eventName: cstring, detail: JsObject): JsObject {.importc: "new CustomEvent".}
proc windowDispatchEvent(event: JsObject) {.importc: "window.dispatchEvent".}
proc dispatchEvent[T](eventName: cstring, detail: T) =
  windowDispatchEvent(
    newCustomEvent(eventName, wrapDetail detail)
  )


#proc addEventListener(cstring: )

var index = -1


type PlayEvent* = object
  uid*: cstring
  ts*: float


type PauseEvent* = PlayEvent
var ws = newWebSocket(
  (
    if location.protocol.to(cstring) == "http:": "ws://" 
    else: "wss://"
  ) & location.host.to(cstring) & cstring"/" & wsPrefix("")
  )

proc sendEvent*[T](eventName: cstring, detail: T) =
  var e = newJsObject()
  e.event = eventName
  e.detail = toJs detail

  ws.send(JSON.stringify(e).to(cstring))

proc windowAddEventListener(event: cstring, callback: JsObject) {.importc: "window.addEventListener".}

template addEventListener*(event: cstring, eventType: typed, body: untyped): (string | cstring, JsObject) {.dirty.} =
  block:
    bind windowAddEventListener
    let callback = proc(e: JsObject) =
      let detail = e.detail.to(eventType)
      body

    windowAddEventListener(event, toJs callback)

    (event, toJs callback)

proc windowRemoveEventListener(event: cstring, callback: JsObject) {.importc: "window.removeEventListener".}
proc removeEventListener*(args: (string | cstring, JsObject)) =
  windowRemoveEventListener(cstring args[0], args[1])

ws.onMessage = proc(e: MessageEvent) =
  if index == -1:
    index = 0 + e.data.toJs.to(int)
    return
  let data = JSON.parse(e.data)
  echo "data"
  console.log(data)
  let event = data.event.to(cstring)
  
  let detail = data.detail

  case $event:
    of "play":
      dispatchEvent("play", detail.to(PlayEvent))
      
    of "pause":
      dispatchEvent("pause", detail.to(PauseEvent))


ws.onOpen = proc (e:Event) =
  ws.send("hello world")
