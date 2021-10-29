import zippy, zippy/ziparchives
import globals
import os
import tables


import streams

const userdataZip = slurp("../../dist/userdata.zip")

let outputStream = newStringStream(userdataZip)


when isMainModule:
  let archive = ZipArchive()
  archive.open(outputStream)
  archive.extractAll("/tmp/volekino")

else:
  proc populateFromZip*() =
    createDir(tmpDir)
    let archive = ZipArchive()
    archive.open(outputStream)
    #[
    for key in archive.contents.keys():
      echo key
    ]#
    try:
      archive.extractAll(tmpDir / "userdata")
    except:
      echo "failed to extract"
      discard
      
    try:
      createDir(USER_DATA_DIR / "..")
      moveDir(tmpDir / "userdata" / "userdata", USER_DATA_DIR)
    except:
      discard
      #echo "error moving userdata ", getCurrentExceptionMsg()

    removeDir(tmpDir / "userdata")
