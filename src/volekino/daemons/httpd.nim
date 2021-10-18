import os, osproc, strtabs, strutils
import ../globals, ../config

proc httpdExecutable: string =
  for exeName in ["httpd", "apache2"]:
    result = findExe(exeName)
    if result.len > 0: break

proc apacheCtlExecutable: string =
  for exeName in ["apachectl", "apache2ctl"]:
    result = findExe(exeName)
    if result.len > 0: break


let apacheEnv = newStringTable({"USER": getEnv("USER"), "USER_DATA_DIR": USER_DATA_DIR, "APACHE_MODULES_DIR": "/usr/lib/apache2/modules/", "APACHE_PID_FILE": USER_DATA_DIR / "httpd.pid"})

proc startHttpd*(conf: VoleKinoConfig): Process =
  #let command = httpdExecutable()
  let command = apacheCtlExecutable()
  if command.len > 0:
    #result = startProcess(command, USER_DATA_DIR, args=["-d", USER_DATA_DIR, "-f", "httpd.conf"], options = {poDaemon, poStdErrToStdOut, poParentStreams, poEchoCmd}, env=apacheEnv)
    result = startProcess(command, USER_DATA_DIR, args=["-d", USER_DATA_DIR, "-f", "httpd.conf", "-k", "start"], options = {poDaemon, poStdErrToStdOut, poParentStreams, poEchoCmd}, env=apacheEnv)


proc shutdownHttpd*(httpdProcess: Process) =
  #let pid = cint parseInt(strip readFile(USER_DATA_DIR / "httpd.pid"))

  let apacheCtl = startProcess(
    apacheCtlExecutable(),
    args=["-d", USER_DATA_DIR, "-f", "httpd.conf", "-k", "stop"],
    env=apacheEnv,
    options={poStdErrToStdOut, poParentStreams}
  )

  echo "apachectl exit code ", apacheCtl.waitForExit()
  echo "httpd exit code ", httpdProcess.waitForExit()
      
  #[
  httpdProcess.terminate()
  echo "httpd exit status ", httpdProcess.waitForExit()
  httpdProcess.close()
  ]#

  removeFile(USER_DATA_DIR / "httpd.pid")
