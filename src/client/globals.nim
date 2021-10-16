import ./jsffi
var
  BASE = location.pathname.split(cstring"/").pop().to(cstring)
  API_PREFIX: cstring


console.log cstring "base = ", BASE
if BASE.len == 0:
  API_PREFIX = cstring"/api/"
else:
  API_PREFIX = BASE & "/api/"



proc apiPrefix*(path: cstring): cstring=
  API_PREFIX & path
  
proc wsPrefix*(path: cstring): cstring=
  apiPrefix(path).replace(cstring"api", cstring"ws")

proc getBackendParam: cstring {.importcpp: "m.parseQueryString(location.search).be || ''".}
var BACKEND = getBackendParam()

proc staticResource*(i: cstring): cstring =
  if BACKEND.len == 0:
    if BASE.len == 0:
      i
    else:
      BASE & i
  else:
    cstring"http://" & BACKEND & cstring":7000" & i

var logstatements*: seq[cstring] = @[]
proc dlog*(s: cstring) =
  logstatements.add s
