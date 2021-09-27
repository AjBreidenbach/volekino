import os, osproc, strtabs, strutils
import ../globals, ../config

proc transmissionDExecutable: string =
  findExe("transmission-daemon")

proc startTransmissionD*(conf: VoleKinoConfig): Process =
  let command = transmissionDExecutable()

  startProcess(command, USER_DATA_DIR, args=["--foreground", "--no-auth", "--config-dir", TMP_DIR, "--download-dir", MEDIA_DIR, "--port", "9092", "--peerport", "51414"], options={poDaemon, poStdErrToStdOut, poParentStreams, poEchoCmd} #[env=env]# )


proc shutdownTransmissionD*(process: Process) =
  process.terminate()
  echo "transmission-daemon exit status ", process.waitForExit()
  process.close()
