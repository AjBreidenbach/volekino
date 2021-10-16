import webview
import globals
import json
import strformat
import models
import models/db_users


proc launchWebview* =
  echo "launchWebview"

  
  var wv =  newWebView(title="VoleKino", url="http://localhost:7000", width=1280, height=720)
  #document.cookie = cstring"session=" & window.volekino.session(true).to(cstring) & cstring"; path=/"

  let otp  = usersDb.createOtpUser(isAdmin=true)
  let session = usersDb.otpLogin(otp, -1)
  let evalStatement = &"document.cookie = 'session={session}; path=/'"
  
  #[
  proc session(p: bool): string =
    usersDb.createSession(userId=0, allowAccountCreation=false)

  wv.bindProc("volekino", "getotp", getotp)
  ]#
  wv.run()
  wv.terminate()

proc startGui* =
  discard invokeSelf("--guiOnly=true")
