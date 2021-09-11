import oids
import std/sha1
from base64 import nil

proc genUid*(): string =
  $secureHash(@ cast[array[12, char]](genOid()))


proc genUidB64*(): string =
  base64.encode(Sha1Digest(secureHash(@ cast[array[12, char]](genOid()))))
  

when isMainModule:
  let uid = genUidB64()
  echo uid, " (", uid.len , ")"
