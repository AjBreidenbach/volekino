import std/jsffi as stdjsffi
export stdjsffi
import asyncjs

proc encodeURI*(s:cstring):cstring {.importc.}
proc newRegExp*(pattern: cstring, modifiers: cstring = ""): JsObject {.importcpp: "new RegExp(@)".}
proc replace*(s:cstring, pattern: cstring | JsObject, replacement:cstring):cstring {.importcpp.}
proc split*(s: cstring, pattern: JsObject | cstring ): seq[cstring] {.importcpp.}
proc getQueryString*: cstring  {.importcpp: r"(m.route.get().match(/\?.*/) || '').toString()".}
proc preserveQuery*(url: cstring): cstring =
  url & getQueryString()
proc getQuery*: JsObject {.importcpp: r"m.parseQueryString((m.route.get().match(/\?.*/) || '').toString())".}
proc getPath*: cstring {.importcpp: r"(m.route.get().match(/.*(?=\?)/) || '').toString()".}
proc join*(s: seq[cstring], c: cstring): cstring {.importcpp.}
proc toLowerCase*(s: cstring): cstring {.importcpp.}
#proc hasOwnProperty*(o: JsObject, s:cstring):bool {.importcpp.}
proc contains*(s1, s2: cstring): bool {.importcpp: "#.includes(@)".}

type TimeoutFunction* = proc(): void
type AsyncTimeoutFunction* = proc(): Future[void]

proc setTimeout*(timeoutFunction: TimeoutFunction | AsyncTimeoutFunction, timeoutDuration: cint): cint {.importc.}
proc setTimeout*(timeoutDuration: cint, timeoutFunction: TimeoutFunction | AsyncTimeoutFunction): cint =
  setTimeout(timeoutFunction, timeoutDuration)
  
proc clearTimeout*(timeoutHandle: cint) {.importc.}

var JSON* {.importc.} : JsObject
proc parseFloat*(s: cstring): float {.importc.}
proc floor*(f: float): int {.importc: "Math.floor".}

converter toCstring*(s: cint | int): cstring = s.toJs.to(cstring)

var document* {.importc.} : JsObject
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
