import webview
import globals



proc launchWebview* =
  echo "launchWebview"
  webview.open(title="VoleKino", url="http://localhost:7000")

proc startGui* =
  discard invokeSelf("--guiOnly=true")
