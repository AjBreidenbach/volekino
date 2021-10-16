import ./jsffi
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
