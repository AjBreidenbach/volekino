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

const apache_modules_dir {.strdefine.}: string = "/usr/lib/apache2/modules/"

  
var
  apacheEnv = newStringTable({"USER": getEnv("USER"), "USER_DATA_DIR": USER_DATA_DIR, "APACHE_MODULES_DIR": getEnv("APACHE_MODULES_DIR", apache_modules_dir), "APACHE_PID_FILE": USER_DATA_DIR / "httpd.pid"})
var apacheArgs = @["-d", USER_DATA_DIR, "-f", "httpd.conf"]


when defined(termux):
  apacheArgs.add ["-D", "StaticModules"]

proc startHttpd*(conf: VoleKinoConfig): Process =
  #let command = httpdExecutable()
  let command = apacheCtlExecutable()
  if command.len > 0:
    #result = startProcess(command, USER_DATA_DIR, args=["-d", USER_DATA_DIR, "-f", "httpd.conf"], options = {poDaemon, poStdErrToStdOut, poParentStreams, poEchoCmd}, env=apacheEnv)
    result = startProcess(command, USER_DATA_DIR, args=(apacheArgs & @[ "-k", "start"]), options = {poDaemon, poStdErrToStdOut, poParentStreams, poEchoCmd}, env=apacheEnv)


proc shutdownHttpd*(httpdProcess: Process) =
  #let pid = cint parseInt(strip readFile(USER_DATA_DIR / "httpd.pid"))

  let apacheCtl = startProcess(
    apacheCtlExecutable(),
    args=(apacheArgs & @["-k", "stop"]),
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
