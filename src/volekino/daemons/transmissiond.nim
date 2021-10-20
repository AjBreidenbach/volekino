import os, osproc, strtabs, strutils, asyncfile, streams, asyncdispatch
import ../globals, ../config

proc transmissionDExecutable: string =
  findExe("transmission-daemon")

proc pipeLoop(process: Process, input: AsyncFile, output: AsyncFile, buffer: pointer) {.async.} =
  while process.peekExitCode == -1:
    while true:
      let bytesRead = await input.readBuffer(buffer, 1024)
      let buf = cast[ptr array[1024, char]](buffer)[]
      var s = newStringOfCap(bytesRead)
      for i in 0..<bytesRead:
        s[i]=buf[i]
      if bytesRead == 0: break
      await output.writeBuffer(buffer, bytesRead)

    await sleepAsync 1000

proc asyncPipe(process: Process, dest: string, mode = fmAppend) {.async.} =
  var 
    buffer : array[1024, char]
    #input: File
  let
    output = openAsync(dest, mode)
  #discard input.open(process.outputHandle, fmRead)
    input = newAsyncFile(process.outputHandle.AsyncFd)
  await pipeLoop(process, input, output, addr buffer)
  

proc startTransmissionD*(conf: VoleKinoConfig): Process =
  let command = transmissionDExecutable()

  result = startProcess(command, USER_DATA_DIR, args=["--foreground", "--no-auth", "--config-dir", TMP_DIR, "--download-dir", MEDIA_DIR, "--port", "9092", "--peerport", "51414"], options={poDaemon, poStdErrToStdOut, poEchoCmd} #[env=env]# )

  
  discard asyncPipe(result, LOG_DIR / "transmission")



proc shutdownTransmissionD*(process: Process) =
  process.terminate()
  echo "transmission-daemon exit status ", process.waitForExit()
  process.close()
