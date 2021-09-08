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
  setCommand("c", getPkgDir() / "src" / "volekino.nim")

task buildAll, "":
  if "-d:release" in commandLineParams():
    exec "nimble -d:release buildFrontend"
    exec "nimble -d:release buildBackend"
  else:
    exec "nimble buildFrontend"
    exec "nimble buildBackend"

requires "nim >= 1.4.8"
requires "https://github.com/planety/prologue.git#05581bf"
requires "https://github.com/MatthewScholefield/appdirs#3cbf5b4"
requires "https://github.com/AjBreidenbach/nim-mithril#697b9f5"
requires "https://github.com/guzba/zippy#14739c9"
requires "cligen"



