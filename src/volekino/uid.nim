import oids
import std/sha1

proc genUid*(): string =
  $secureHash(@ cast[array[12, char]](genOid()))


when isMainModule:
  echo genUid()
