import jsffi


proc getCurrentTime*(uid: cstring): float =
  let record = localStorage[uid & cstring":currentTime"]
  result = parseFloat(record)

  if result.isFalsey: result = 0.0
  #console.log cstring"getCurrentTime", result


proc setCurrentTime*(uid: cstring, currentTime: JsObject) =
  localStorage[uid & cstring":currentTime"] = currentTime.to(cstring)

proc setCurrentTime*(uid: cstring, currentTime: cstring) =
  localStorage[uid & cstring":currentTime"] = currentTime

  
