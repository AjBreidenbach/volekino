import net, strutils
import strutils, re
import models/db_appsettings
import config/default_settings
import ../common/user_types
import tables, json

type VoleKinoConfig* = ref object
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

proc sessionDuration*(config: VoleKinoConfig): int =
  try:
    result = parseInt config.appSettings.getProperty("session-duration")
  except: result = 168

  result *= 3600

proc otpExpirationPeriod*(config: VoleKinoConfig): int =
  try:
    result = parseInt config.appSettings.getProperty("otp-expiration-period")
  except: result = 1

  result *= 3600


let SPLIT_RE = re"\s,"
proc subtitleLanguages*(config: VoleKinoConfig): seq[string] =
  result = config.appSettings.getProperty("subtitle-langs").split(SPLIT_RE)
  if result.len == 1 and result[0] == "none":
    discard result.pop()
  elif result.len == 0:
    result.add "eng"


proc `subtitleLanguages=`*(config: var VoleKinoConfig, languages: seq[string]) =
  config.appSettings.setProperty("subtitle-langs", languages.join(", "))
 
proc applySettings*(config: VoleKinoConfig, settings: ApplySettingsRequest) =
  for setting in settings:
    config.appSettings.setProperty(setting.key, setting.value)

proc getSettings*(config: VoleKinoConfig): seq[AppSetting] =
  result = getDefaultSettings()
  let appliedSettings = config.appSettings.getAllProperties()

  for (key, value) in appliedSettings.pairs:
    let value = try:
      parseJson(value)
    except: newJString(value)

    for setting in result:
      if setting.name == key:
        setting.value = value

