import ./jsffi
import mithril
import asyncjs

const LOGGED_OUT = cstring"not logged in"
const PLAIN_USER = cstring"logged in"
const AS_ADMIN = cstring"logged in as admin"


var
  BASE = location.pathname.split(cstring"/").slice(-2).join(cstring"/").to(cstring)
  API_PREFIX: cstring
  LOGIN_STATUS = LOGGED_OUT
  AUTH_METHOD: int


if BASE == cstring"/":
  BASE = cstring""
  API_PREFIX = cstring"/api/"
else:
  BASE = cstring"/" & BASE
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


proc loadLoginStatus() {.async.} =
  try:
    let response = await mrequest(apiPrefix"users/me")
    if isTruthy response.isAdmin:
      LOGIN_STATUS = AS_ADMIN
    else:
      LOGIN_STATUS = PLAIN_USER

    if isTruthy response.authMethod:
      AUTH_METHOD = response.authMethod.to(int)

  except: discard

let baseQueryString = decodeURIComponent(location.search.to(cstring))
if baseQueryString.len == 29:
  dlog(cstring "query = " & baseQueryString)
  document.cookie = cstring"session="& decodeURIComponent(location.search.to(cstring).slice(1))

discard loadLoginStatus()

proc isLoggedIn*(): bool =
  #console.log cstring "loginStatus",  state.loginStatus
  LOGIN_STATUS != LOGGED_OUT



proc isAdmin*(): bool =
  LOGIN_STATUS == AS_ADMIN

proc isRegistered*(): bool  =
  AUTH_METHOD == 0
  #echo "#isRegistered ", result
  
proc canRegister*(): bool =
  AUTH_METHOD == 3


