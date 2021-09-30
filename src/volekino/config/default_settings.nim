import os
import json
import ../../common/user_types
#const DEFAULTS_FILE = ".." / ".." / ".." / "default-settings.yml"
#const DEFAULT_SETTINGS_JSON = gorge("npx --no-warnings yaml json write " & quoteShell(DEFAULTS_FILE))

const DEFAULTS_FILE = ".." / ".." / ".." / "default-settings.yml"
const SCRIPT_FILE = ".." / ".." / ".." /  "node_modules" / "yaml-cli" / "lib" / "json.js"
const COMMAND = "node --no-warnings " & quoteShell(SCRIPT_FILE) & " write " & quoteShell(DEFAULTS_FILE)
const DEFAULT_SETTINGS_JSON = gorge(COMMAND)

#echo DEFAULT_SETTINGS_JSON
let defaultSettingsJson = parseJson DEFAULT_SETTINGS_JSON

var defaultSettings = newSeq[AppSetting]()
#when isMainModule:
for (settingName, settingValue) in defaultSettingsJson.pairs:
    #echo settingName
  let setting = AppSetting(
    name: settingName,
    default: settingValue["default"],
    value: settingValue["default"],
    description: settingValue["description"].getStr(),
    selector: settingValue["selector"].getStr(),
    requiresRestart: settingValue.getOrDefault("requiresRestart").getBool()
  )
  defaultSettings.add setting
  #echo defaultSettings.pretty


proc getDefaultSettings*: seq[AppSetting] = result = defaultSettings
