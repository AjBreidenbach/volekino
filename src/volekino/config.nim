import net, strutils
import strutils, re
import models/db_appsettings

type VoleKinoConfig* = object
  appSettings: AppSettings
  

proc port*(config: VoleKinoConfig): Port =
  let property = config.appSettings.getProperty("port")
  try:
    Port parseInt(property)
  except:
    Port(7001)


proc `port=`*(config: VoleKinoConfig, port: Port) =
  config.appSettings.setProperty($port)

proc loadConfig*(appSettings: AppSettings): VoleKinoConfig =
  VoleKinoConfig(appSettings: appSettings)
  
  
proc requireAuth*(config: VoleKinoConfig): bool =
  try:
    parseBool config.appSettings.getProperty("require-auth")
  except: false

proc `requireAuth=`*(config: var VoleKinoConfig, require: bool) =
  config.appSettings.setProperty("require-auth", $require)
  
let SPLIT_RE = re"\s,"
proc subtitleLanguages*(config: VoleKinoConfig): seq[string] =
  result = config.appSettings.getProperty("subtitle-langs").split(SPLIT_RE)
  if result.len == 1 and result[0] == "none":
    discard result.pop()
  elif result.len == 0:
    result.add "eng"


proc `subtitleLanguages=`*(config: var VoleKinoConfig, languages: seq[string]) =
  config.appSettings.setProperty("subtitle-langs", languages.join(", "))
 
