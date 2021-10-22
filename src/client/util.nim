import ./jsffi, ./globals
import mithril
template handleErrorCodes*(body: untyped): untyped =
  try:
    body
  except:
    bind getJsException
    bind mrouteset
    let ex = getJsException()
    case ex.code.to(int):
      of 401:
        discard setTimeout(cint 1000, TimeoutFunction(proc = mrouteset("/login")))
        return
      else: discard
proc reload* {.async.} =
  echo "reloading page"
  try:
    discard (await mrequest(apiPrefix"restart", Post))
  except:
    discard
  finally:
    discard setTimeout(cint 2000, location.reload.bind(window.location).to(TimeoutFunction))
 

proc logout* {.async.} =
  discard await mrequest(apiPrefix"/logout", Post)
  location.reload()
