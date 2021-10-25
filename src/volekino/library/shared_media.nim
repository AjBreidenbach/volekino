import os, strformat, strutils, asyncdispatch
import ../globals, ../mimes
import ../../common/library_types
import tables
import transmission_remote

proc localIterator: iterator: string =
  let getSharedLocal = iterator : string =
    for (kind, path) in walkDir(MEDIA_DIR):
      case kind:
      of pcLinkToFile, pcLinkToDir:
        let (_, name, ext) = splitFile(path)
        yield name & ext
      else:
        discard
  getSharedLocal

proc removeSharedLocal(m: string) =
  let path = MEDIA_DIR / m
  removeFile(path)
 
var torrentIds =  newTable[string, int]()

proc getSharedMedia*: Future[seq[AddedMediaEntry]] {.async.} =
  let getSharedLocal = localIterator()
  for f in getSharedLocal():
    result.add AddedMediaEntry(
      name: f,
      kind: (
        if getMime(f).startsWith("video/"): MediaMediaEntry
        else: DirMediaEntry
      )
    )

  for t in await transmission.getAllTorrents(Key.id, Key.name):
    torrentIds[t.name] = t.id
    result.add AddedMediaEntry(
      name: t.name,
      kind: TorrentEntry
    )
    

proc iteratorIncludesMedia(s: iterator: string, m: string): bool =
  for sn in s():
    if sn == m: return true

proc removeSharedMedia*(m: string) {.async.} =
  if iteratorIncludesMedia(localIterator(), m):
    removeSharedLocal(m)
  elif m in torrentIds:
    let id = torrentIds[m]
    await transmission.removeTorrentAndData(id)
  else:
    raise newException(CatchableError, &"Media ({m}) not found")
  runSync()




#proc removeSharedMedia*

when isMainModule:
  echo getSharedMedia()
