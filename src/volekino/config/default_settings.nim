import os
import json
#const DEFAULTS_FILE = ".." / ".." / ".." / "default-settings.yml"
#const DEFAULT_SETTINGS_JSON = gorge("npx --no-warnings yaml json write " & quoteShell(DEFAULTS_FILE))

const DEFAULTS_FILE = ".." / ".." / ".." / "default-settings.yml"
const SCRIPT_FILE = ".." / ".." / ".." /  "node_modules" / "yaml-cli" / "lib" / "json.js"
const COMMAND = "node --no-warnings " & quoteShell(SCRIPT_FILE) & " write " & quoteShell(DEFAULTS_FILE)
const DEFAULT_SETTINGS_JSON = gorge(COMMAND)

let defaultSettings* = parseJson DEFAULT_SETTINGS_JSON

when isMainModule:
  echo defaultSettings.pretty

