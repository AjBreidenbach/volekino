import globals
import json, strformat, uri
import models
import models/db_users
import os, osproc
import terminal
const ui_launcher {.strdefine.}: string ="webview"
when ui_launcher == "webview":
  import webview


proc launchWebview* =
  echo "launchWebview"
  echo "ui launcher: ", ui_launcher

  let
    otp  = usersDb.createOtpUser(isAdmin=true)
    session = usersDb.otpLogin(otp, -1)
    destination = &"http://localhost:7000?{encodeUrl(session)}"

  
  when ui_launcher == "webview":
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
  else:

    let launcher = findExe(ui_launcher)
    if launcher.len == 0:
      styledecho fgRed, "couldn't start open ui"
      return

    let process = startProcess(ui_launcher, args=[destination], options={poEchoCmd, poStdErrToStdOut, poParentStreams})
    echo "launcher exited with ", process.waitForExit()


proc startGui* =
  discard invokeSelf("--guiOnly=true")
