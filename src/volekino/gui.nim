import webview
import globals
import json
import strformat
import uri
import models
import models/db_users


proc launchWebview* =
  echo "launchWebview"

  
  let otp  = usersDb.createOtpUser(isAdmin=true)
  let session = usersDb.otpLogin(otp, -1)
  let destination = &"http://localhost:7000?{encodeUrl(session)}"
  var wv =  newWebView(title="VoleKino", url= destination , width=1280, height=720)
  #document.cookie = cstring"session=" & window.volekino.session(true).to(cstring) & cstring"; path=/"

  #let evalStatement = &"document.cookie = 'session={session}; path=/'"
  
  #[
  proc session(p: bool): string =
    usersDb.createSession(userId=0, allowAccountCreation=false)

  wv.bindProc("volekino", "getotp", getotp)
  ]#
  wv.run()
  wv.terminate()

proc startGui* =
  discard invokeSelf("--guiOnly=true")
