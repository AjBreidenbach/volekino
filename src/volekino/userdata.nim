import zippy, zippy/ziparchives
import globals
import os


import streams

const userdataZip = slurp("../../dist/userdata.zip")

let outputStream = newStringStream(userdataZip)


when isMainModule:
  let archive = ZipArchive()
  archive.open(outputStream)
  archive.extractAll("/tmp/volekino")

else:
  proc populateFromZip*() =
    let archive = ZipArchive()
    archive.open(outputStream)
    try:
      archive.extractAll(tmpDir)
    except:
      discard

    try:
      createDir(USER_DATA_DIR / "..")
      moveDir(tmpDir / "userdata", USER_DATA_DIR)
    except:
      discard


