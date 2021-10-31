import os, mimetypes, strutils, times, strformat
import ./globals
import ../common/library_types



let
  mimes = newMimetypes()
  homeDir = getHomeDir()

proc ls*(dir: string): seq[FileEntry] =
  let cwd = homeDir / normalizedPath(dir)
  for (kind, path) in walkDir(cwd):
    var entryType = InvalidFileEntry

    let
      (_, name, ext)= path.splitFile()

    if name.startsWith("."):
      continue
    elif kind == pcDir or kind == pcLinkToDir:
      entryType = DirFileEntry
    else:
      let mime = mimes.getMimetype(ext)

      if mime.startsWith("video/"):
        entryType = MediaFileEntry

    var filename = name
    if ext.len > 0:
      filename.add ext

    if entryType != InvalidFileEntry:
      result.add(FileEntry(filename: filename, kind: entryType, lastModified: getFileInfo(path).lastWriteTime.toUnixFloat()))

type RecursiveLibraryError* = object of CatchableError
proc symlinkMedia*(target: string) =
  let normalized = normalizedPath(target)
  let (_, name, ext) = normalized.splitFile()

  if MEDIA_DIR.startsWith(normalized):
    raise newException(RecursiveLibraryError, &"{normalized} is a parent directory of VoleKino ({MEDIA_DIR})")
  
  createSymLink(homeDir / normalized, MEDIA_DIR / name & ext)
  runSync()
  
when isMainModule:
  import json
  echo (% ls(""))
