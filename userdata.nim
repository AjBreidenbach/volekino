import zippy, zippy/ziparchives
import os
import re
import tables

let whiteList = @[
  #re"((images(/.*)?)|static|media|library|logs|subtitles|thumbnails|\.htaccess|\.conf)$",
  re"((images/.*)|static/|media/|library/|logs/|subtitles/|thumbnails/|\.htaccess|\.conf|\.types)$",
]

proc whitelisted(path: string): bool =
  for pattern in whiteList:
    if pattern in path: return true
  false



proc writeUserDataTemplate* =
  var t = ZipArchive()
  t.addDir("userdata")

  var ignoreFiles = newSeq[string]()

  for key in t.contents.keys:
    if not whitelisted(key):
      #echo "discarding ", key
      ignoreFiles.add(key)
    else:
      echo "keeping ", key

  for f in ignoreFiles:
    t.contents.del(f)

  t.writeZipArchive("dist/userdata.zip")

#t.writeZipArchive("/tmp/test.zip")

when isMainModule:
  writeUserDataTemplate()
