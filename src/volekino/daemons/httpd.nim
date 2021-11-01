import os, osproc, strtabs, strutils
import ../globals, ../config
import ./daemon_util

#[
proc httpdExecutable: string =
  for exeName in ["httpd", "apache2"]:
    result = findExe(exeName)
    if result.len > 0: break
]#

const EXE_NAMES = ["apachectl", "apache2ctl", "httpd", "apache2"]

proc apacheCtlExecutable: string =
  for exeName in EXE_NAMES:
    result = findExe(exeName)
    if result.len > 0:
      break
  if result.len == 0:
    raise newException(CatchableError, "apache exe not found in path " & getEnv("PATH"))


const apache_modules_dir {.strdefine.}: string = "/usr/lib/apache2/modules/"

  
var
  apacheEnv = newStringTable({"USER": getEnv("USER"), "USER_DATA_DIR": USER_DATA_DIR, "APACHE_MODULES_DIR": getEnv("APACHE_MODULES_DIR", apache_modules_dir), "APACHE_PID": APACHE_PID})
var apacheArgs = @["-d", USER_DATA_DIR, "-f", "httpd.conf"]

when defined(termux):
  apacheArgs.add ["-D", "StaticModules"]

proc apacheCtlStop: Process =
  startProcess(
    apacheCtlExecutable(),
    args=(apacheArgs & @["-k", "stop"]),
    env=apacheEnv,
    options={poStdErrToStdOut, poParentStreams}
  )

proc startHttpd*(conf: VoleKinoConfig): Process =
  let command = apacheCtlExecutable()

  if getPidName(APACHE_PID) in EXE_NAMES:
    echo "apache was still running - signalling to stop"
    let apacheCtl = apacheCtlStop()
    echo "apachectl exit code ", apacheCtl.waitForExit()

  

  if command.len > 0:
    echo "apache status: ", execProcess(command, args=(@["-t"] & apacheArgs), env=apacheEnv, options = {poStdErrToStdOut})
    result = startProcess(command, USER_DATA_DIR, args=(apacheArgs & @[ "-k", "start"]), options = {poDaemon, poStdErrToStdOut, poParentStreams, poEchoCmd}, env=apacheEnv)


proc shutdownHttpd*(httpdProcess: Process) =
  #let pid = cint parseInt(strip readFile(USER_DATA_DIR / "httpd.pid"))

  let apacheCtl = apacheCtlStop()

  echo "apachectl exit code ", apacheCtl.waitForExit()
  echo "httpd exit code ", httpdProcess.waitForExit()
      
  #[
  httpdProcess.terminate()
  echo "httpd exit status ", httpdProcess.waitForExit()
  httpdProcess.close()
  ]#

  removeFile(USER_DATA_DIR / "httpd.pid")
