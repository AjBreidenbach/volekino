import regex, strutils

const settingsRe = re"(?P<a>[a-z\-]+)\s*(\=|\:)?\s*(?P<b>[^\n;,]+)"


type ParsedSetting* = tuple[key, value: string]

proc key(input: string, m: RegexMatch): string =
  for g in m.group("a"):
    result = input[g]
    break

proc value(input: string, m: RegexMatch): string =
  for g in m.group("b"):
    result = input[g]
    break
  result = result.strip()
  


iterator parseSettings*(input: string): ParsedSetting =
  var offset = 0
  var m: RegexMatch
  while offset < input.len:
    if find(input, settingsRe, m, offset):
      yield (key(input,m), value(input,m))
      offset = cast[array[2, int]](m.boundaries)[1] + 1
    else: break
    


when isMainModule:
  for (key, value) in parseSettings("""
    port 7000, local-proxy-pass=false ;proxy-server: volekino.abreidenbach.com
    require-auth true
    proxy-server-token=andrew:abc123
  """):
    echo key, " :: ", value
    
  

