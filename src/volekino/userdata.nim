import zippy, zippy/ziparchives
import uid
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
  let prefix = genUid()
  proc populateFromZip*() =
    createDir(tmpDir)
    let archive = ZipArchive()
    archive.open(outputStream)
    #[
    for key in archive.contents.keys():
      echo key
    ]#
    try:
      archive.extractAll(tmpDir / prefix)
    except:
      #echo "failed to extract"
      discard
      
    #createDir(USER_DATA_DIR / "..")
    #moveDir(tmpDir / "userdata" / "userdata", USER_DATA_DIR)
    createDir(USER_DATA_DIR)
    for file in walkPattern(tmpDir / prefix / "userdata" / "*"):
      let
        (_, name, ext) = splitFile(file)
        basename = name & ext
      try:
        moveFile(
          file,
          USER_DATA_DIR / basename
        )
        
      except:
        discard
        try:
          moveDir(
            file,
            USER_DATA_DIR / name
          )
        except:
          discard
      #echo "error moving userdata ", getCurrentExceptionMsg()

    try:
      removeDir(tmpDir / prefix / "userdata")
      removeDir(tmpDir / prefix)
    except: discard
