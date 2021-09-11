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
        mrouteset("/login")
        return
      else: discard
