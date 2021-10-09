# Package
import os
#import userdata

version       = "0.1.0"
author        = "Andrew Breidenbach"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
bin           = @["volekino"]

switch("outdir", "dist")


task compileFrontend, "":
  if "-d:release" in commandLineParams():
    switch("define", "release")
  setCommand("js",  getPkgDir() / "src" / "client.nim")

task buildFrontend, "build client side code":
  if "-d:release" in commandLineParams():
    exec "nimble -d:release compileFrontend"
    exec "npx terser -o dist/client.min.js --mangle toplevel,reserved=['m'] dist/client.js"
    exec "node scripts" / "render-client.js prod"
  else:
    exec "nimble compileFrontend"
    exec "node scripts" / "render-client.js"

task buildBackend, "build server code":
  exec "nim c -r userdata"
  if "-d:release" in commandLineParams():
    switch("define", "release")
  switch("define", "usestd")
  setCommand("c", getPkgDir() / "src" / "volekino.nim")

task buildAll, "":
  if "-d:release" in commandLineParams():
    exec "nimble -d:release buildFrontend"
    exec "nimble -d:release buildBackend"
  else:
    exec "nimble buildFrontend"
    exec "nimble buildBackend"


task buildDebian, "":
  exec "nimble -d:release buildAll"
  exec "cp dist/volekino debian/volekino_0.1.0_amd64/usr/bin/"
  exec "dpkg-deb --build debian/volekino_0.1.0_amd64/"
  #discard
#task packageDeban

requires "nim >= 1.4.8"
requires "https://github.com/planety/prologue.git#05581bf"
requires "https://github.com/MatthewScholefield/appdirs#3cbf5b4"
requires "https://github.com/AjBreidenbach/nim-mithril#141d4ec"
#requires "mithril" #development
requires "https://github.com/guzba/zippy#14739c9"
requires "https://github.com/stisa/jswebsockets#ff0ceec"
requires "https://github.com/AjBreidenbach/nim-transmission-remote#aa2a025"
requires "https://github.com/oskca/webview#head"
requires "psutil"
#requires "transmission_remote" #development
requires "nimcrypto"
requires "websocketx >= 0.1.2"
requires "cligen"



