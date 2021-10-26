import strutils
import ../globals
when defined(windows):
  import psutil/psutil_windows as psutil
else:
  import psutil/psutil_linux as psutil


proc getPidName*(pidFile: string): string =
  try:
    let 
      pid = parseInt strip(readFile(pidFile))
      name = pid_name(pid)

    #[
    if name.startsWith("transmission"):
      when defined(posix):
        if kill(Pid pid, cint SIGTERM) == 0:
          echo "terminated running transmission daemon"
        else:
          echo "couldn't terminate running transmission daemon"
      else:
        echo "transmission already running"
        return
    ]#

    return name

  except IOError:
    discard


