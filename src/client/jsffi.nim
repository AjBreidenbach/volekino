import std/jsffi as stdjsffi
export stdjsffi
import asyncjs

proc startsWith*(s1,s2:cstring):bool {.importcpp.}
proc endsWith*(s1,s2:cstring):bool {.importcpp.}
proc encodeURI*(s:cstring):cstring {.importc.}
proc encodeURIComponent*(s:cstring):cstring {.importc.}
proc newRegExp*(pattern: cstring, modifiers: cstring = ""): JsObject {.importcpp: "new RegExp(@)".}
proc replace*(s:cstring, pattern: cstring | JsObject, replacement:cstring):cstring {.importcpp.}
proc split*(s: cstring, pattern: JsObject | cstring ): seq[cstring] {.importcpp.}
proc getQueryString*: cstring  {.importcpp: r"(m.route.get().match(/\?.*/) || '').toString()".}
proc preserveQuery*(url: cstring): cstring =
  url & getQueryString()
proc getQuery*: JsObject {.importcpp: r"m.parseQueryString((m.route.get().match(/\?.*/) || '').toString())".}
proc getPath*: cstring = #{.importcpp: r"(m.route.get().match(/.*(?=\?)/) || '').toString()".}
  asm """
    let route = m.route.get()
    return (route.match(/.*(?=\?)/) || route).toString()
  """
proc join*(s: seq[cstring], c: cstring): cstring {.importcpp.}
proc toLowerCase*(s: cstring): cstring {.importcpp.}
#proc hasOwnProperty*(o: JsObject, s:cstring):bool {.importcpp.}
proc contains*(s1, s2: cstring): bool {.importcpp: "#.includes(@)".}

type TimeoutFunction* = proc(): void
type AsyncTimeoutFunction* = proc(): Future[void]

proc setTimeout*(timeoutFunction: TimeoutFunction | AsyncTimeoutFunction, timeoutDuration: cint): cint {.importc.}
proc setTimeout*(timeoutDuration: cint, timeoutFunction: TimeoutFunction | AsyncTimeoutFunction): cint =
  setTimeout(timeoutFunction, timeoutDuration)

template timeout*(timeoutDuration: int, body: untyped): untyped =
  setTimeout(
    timeoutDuration,
    TimeoutFunction ( proc: void = (body) )
  )
  
proc clearTimeout*(timeoutHandle: cint) {.importc.}
proc slice*(s:cstring,i:cint):cstring {.importcpp.}
proc slice*(s:cstring,i,j:cint):cstring {.importcpp.}
proc slice*[T](s: seq[T],i:cint):seq[T] {.importcpp.}
proc slice*[T](s: seq[T],i,j:cint):seq[T] {.importcpp.}
converter toCstring(c: char): cstring {.importc: "String.fromCharCode".}
proc rfind*(s:cstring,c:cstring): cint {.importcpp: "lastIndexOf".}
proc rfind*(s:cstring,c:char): cint = rfind(s,cstring c)
proc localeCompare*(s1,s2:cstring):int {.importcpp.}
proc sort*[T](a: var openArray[T], cmp: proc (x, y: T): int) {.importcpp.}
proc decodeURI*(s:cstring):cstring {.importc.}
proc decodeURIComponent*(s:cstring):cstring {.importc.}
proc deepCopy*[T](y: seq[T]): seq[T] {.importcpp: "slice".}
proc newDate*[T](t: T): JsObject {.importcpp: "new Date(#)".}

var JSON* {.importc.} : JsObject
proc parseFloat*(s: cstring): float {.importc.}
proc floor*(f: float): int {.importc: "Math.floor".}

converter toCstring*(s: cint | int): cstring = s.toJs.to(cstring)

var document* {.importc.} : JsObject
var window* {.importc.} : JsObject
var navigator* {.importc.} : JsObject
var location* {.importc.} : JsObject
var console* {.importc.} : JsObject
var localStorage* {.importc.}: JsAssoc[cstring, cstring]

type JsSet* = ref object
  assoc: JsAssoc[cstring, bool]
  length: int


proc newJsSet*(): JsSet = JsSet(assoc:newJsAssoc[cstring,bool](), length: 0)
proc len*(s: JsSet): int = s.length


proc contains*(s: JsSet, key: cstring): bool =
  s.assoc[key]
  
proc inc(s: var JsSet) = s.length += 1
proc dec(s: var JsSet) = s.length -= 1

proc parseInt*(s: cstring | JsObject): int {.importc.}
proc toFixed*(f: float, places: int) {.importcpp.}
proc excl*(s1: var JsSet, s2: JsSet) =
  for (key, value) in s2.assoc.pairs:
    if value:
      if not s1.assoc[key]:
        dec s1
        s1.assoc[key] = false


proc clone*(o: JsObject):JsObject {.importcpp: "Object.assign({}, @)".}
proc excl*(s1: var JsSet, key: cstring) =
  if s1.assoc[key]:
    dec s1
  s1.assoc[key] = false

proc incl*(s1: var JsSet, key: cstring) =
  if not s1.assoc[key]:
    inc s1
  s1.assoc[key] = true

proc incl*(s1: var JsSet, s2: JsSet) =
  for (key, value) in s2.assoc.pairs:
    if value:
      if not s1.assoc[key]:
        inc s1
      s1.assoc[key] = true

iterator items*(s: JsSet):cstring =
  for (key, value) in s.assoc.pairs:
    if value: yield key

proc isFalsey*[T](jsval: T):bool {.importcpp: "!@".}
proc isTruthy*[T](jsval: T):bool {.importcpp: "!!@".}

proc getJsException*: JsObject {.exportc.}=
  asm """if (lastJSError && ! lastJSError.m_type) return lastJSError"""

proc addCallback*[T](f: Future[T], cb: proc(t: T)) {.importcpp: "#.catch(e => e).then(@)".}

proc all*[T](futs: varargs[Future[T]]): Future[seq[T]] {.importc: "Promise.all".}
