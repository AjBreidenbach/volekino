import os, osproc, strtabs, strutils
import ../globals, ../config

when defined(windows):
  import winlean
else:
  import posix

proc httpdExecutable: string =
  for exeName in ["httpd", "apache2"]:
    result = findExe(exeName)
    if result.len > 0: break


proc startHttpd*(conf: VoleKinoConfig): Process =
  let env = newStringTable({"USER": getEnv("USER"), "USER_DATA_DIR": USER_DATA_DIR, "APACHE_MODULES_DIR": "/usr/lib/apache2/modules/"})
  let command = httpdExecutable()
  if command.len > 0:
    result = startProcess(command, USER_DATA_DIR, args=["-d", USER_DATA_DIR, "-f", "httpd.conf"], options = {poDaemon, poStdErrToStdOut, poParentStreams, poEchoCmd}, env=env)


proc shutdownHttpd*(httpdProcess: Process) =
  let pid = cint parseInt(strip readFile(USER_DATA_DIR / "httpd.pid"))
  when defined(windows):
    #TODO kill apache
    echo "not killing apache on windows???"
  else:
    let status = kill(pid, SIGTERM)
    echo "terminate apache ", $status
    
  httpdProcess.terminate()
  echo "httpd exit status ", httpdProcess.waitForExit()
  httpdProcess.close()
