import jsffi


var popupEnabled* = false
var `$shouldHidePopup` = localStorage[cstring"shouldHidePopup"] == cstring"1"

proc shouldHidePopup*: bool = `$shouldHidePopup`
proc hidePopup* =
  `$shouldHidePopup` = true
  localStorage[cstring"shouldHidePopup"] = cstring"1"
proc showPopup* =
  `$shouldHidePopup` = false
  localStorage[cstring"shouldHidePopup"] = cstring"0"


proc getCurrentTime*(uid: cstring): float =
  let record = localStorage[uid & cstring":currentTime"]
  result = parseFloat(record)

  if result.isFalsey: result = 0.0
  #console.log cstring"getCurrentTime", result


proc setCurrentTime*(uid: cstring, currentTime: JsObject) =
  localStorage[uid & cstring":currentTime"] = currentTime.to(cstring)

proc setCurrentTime*(uid: cstring, currentTime: cstring) =
  localStorage[uid & cstring":currentTime"] = currentTime

  

proc conversionSetJobId*(uid: cstring, jobId: int) =
  localStorage[uid & cstring":convertJobId"] = jobId

proc conversionGetJobId*(uid: cstring): int =
  try:
    result = parseInt localStorage[uid & cstring":convertJobId"]
    if result.isFalsey(): return -1
  except: return -1
  
proc conversionDeleteJobId*(uid: cstring) =
  discard jsDelete localStorage[uid & cstring":convertJobId"]
