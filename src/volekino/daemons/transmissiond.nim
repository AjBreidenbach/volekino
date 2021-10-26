import os, osproc, strtabs, strutils
import ../globals, ../config, ../pipe
when defined(posix):
  import posix


proc transmissionDExecutable: string =
  findExe("transmission-daemon")

 

proc startTransmissionD*(conf: VoleKinoConfig): Process =
  let command = transmissionDExecutable()
  try:
    let 
      pid = parseInt readFile(TRANSMISSION_PID)
      name = pid_name(pid)

    if name.startsWith("transmission"):
      when defined(posix):
        if kill(Pid pid, cint SIGTERM) == 0:
          echo "terminated running transmission daemon"
        else:
          echo "couldn't terminate running transmission daemon"
      else:
        echo "transmission already running"
        return

  except IOError:
    discard

  result = startProcess(command, USER_DATA_DIR, args=["--foreground", "--no-auth", "--config-dir", TMP_DIR, "--download-dir", MEDIA_DIR, "--port", "9092", "--peerport", "51414", "--pid-file", TRANSMISSION_PID], options={poDaemon, poStdErrToStdOut, poEchoCmd} #[env=env]# )

  
  discard asyncPipe(result, LOG_DIR / "transmission")



proc shutdownTransmissionD*(process: Process) =
  process.terminate()
  echo "transmission-daemon exit status ", process.waitForExit()
  process.close()
