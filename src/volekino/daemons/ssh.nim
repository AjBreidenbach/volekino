import ../globals, ../config
import os, osproc, strutils, strformat, streams, asyncdispatch, strtabs

proc getProxyPassword*(conf: VoleKinoConfig): string =
  try: conf.proxyServerToken.split(':')[1]
  except: ""

#[
proc sshControlLoop(ssh: Process, password: string){.async.} =
  var line: string
  let
    output = ssh.outputStream

  while true:
    if output.atEnd:
      await sleepAsync 100
    else:
      discard output.readLine(line)
]#
      
proc startSshTunnel*(conf: VoleKinoConfig, retry=true): Process =
  let sshCommand = findExe("ssh")
  let command = findExe("setsid")

  if sshCommand.len + command.len > 0:
    let
      token = conf.proxyServerToken
      proxyServer = conf.proxyServer
      port = 2222
      env=newStringTable({"VOLEKINO_HOME": USER_DATA_DIR, "SSH_ASKPASS": getAppFilename(), "SSH_ASKPASS_REQUIRE": "force", "DISPLAY": "nothing:0"})
    var 
      username = ""
      password = ""
    try:
      let sp = token.split(':')
      username = sp[0]
      password = sp[1]
    except: discard

    result = startProcess(
      command,
      env=env,
      args=[sshCommand, "-v", proxyServer, "-p", $port, "-o", "StrictHostKeyChecking=no", "-o", "PreferredAuthentications=password", "-o", "ServerAliveInterval=60", "-l", username, "-R", &"/tmp/{username}:0.0.0.0:7000", "-N"],
      options={poEchoCmd, poStdErrToStdOut}
    )

    let output = result.outputStream
    var line: string
    while true:
      if not atEnd(output):
        discard output.readLine(line)
        echo "[ssh:] ", line
        if line.contains("Permission denied"):
          echo "password incorrect? ", password
          return
        if line.contains("remote forward success"):
          echo "forward successful"
          return
        elif line.contains("remote forward failure"):
          echo "failed to forward"
          result.terminate()
          discard result.waitForExit()
          if retry:
            sleep 5000
            echo "trying again"
            return conf.startSshTunnel(false)
      else:
        sleep 10


when isMainModule:
  import ../models
  import ../models/db_appsettings

  createDir(TMP_DIR)
  let db = initDb(TMP_DIR, {0})[0]
  appSettings.setProperty("proxy-server", "172.17.0.2")
  appSettings.setProperty("proxy-server-token", "andrew:zhopa")
  let conf =loadConfig(appSettings)

  if existsEnv("SSH_ASKPASS"):
    echo conf.getProxyPassword()
    quit 0
  let ssh = conf.startSshTunnel()
  echo "waiting for exit"
  echo ssh.waitForExit


#ssh -v 172.17.0.2 -p 2222 -R 7000:0.0.0.0:7000 -N [0] 0:fish* 1:nvim- 2:fish                                                                       "fish /home/andrew/pro
