import ./jsffi
var API_PREFIX = location.pathname.split(cstring"/").pop().to(cstring)
if API_PREFIX.len == 0:
  API_PREFIX = cstring"/api/"
else:
  API_PREFIX = API_PREFIX & "/api/"



proc apiPrefix*(path: cstring): cstring=
  API_PREFIX & path
  
proc wsPrefix*(path: cstring): cstring=
  apiPrefix(path).replace(cstring"api", cstring"ws")

proc getBackendParam: cstring {.importcpp: "m.parseQueryString(location.search).be || ''".}
var BACKEND = getBackendParam()

proc staticResource*(i: cstring): cstring =
  if BACKEND.len == 0:
   i
  else:
    cstring"http://" & BACKEND & cstring":7000" & i
