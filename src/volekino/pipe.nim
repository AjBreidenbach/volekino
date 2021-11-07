import asyncfile, osproc, asyncdispatch, selectors, epoll, posix

type PipeCb* = proc(line: string): void

proc pipeLoop(process: Process, input: AsyncFile, output: AsyncFile, buffer: var string, cb: PipeCb = nil) {.async.} =
  const EPOLL_EVENTS = 8

  var 
    epollfd = epoll_create1(O_CLOEXEC)
    evt = EpollEvent(events: EPOLLIN)
    epollEvents: array[EPOLL_EVENTS, EpollEvent]

  evt.data.u64 = uint64 process.outputHandle
  let epoll_ctl_result = epoll_ctl(epollfd, EPOLL_CTL_ADD, cint process.outputHandle, addr evt)
  if not epoll_ctl_result == 0:
    echo "non-zero epoll_ctl result: ", epoll_ctl_result

  #echo "epoll_ctl_result: ", epoll_ctl_result

  #while selector.selectInto(-1, selectionResults) > 0:
  
  while process.peekExitCode == -1:
    while true:
      let epoll_wait_result = epoll_wait(epollfd, cast[ptr EpollEvent](addr epollEvents), 1, EPOLL_EVENTS)
      if epoll_wait_result == 0: break
      # can't use a buffer here
      var line = await input.readLine()
      if not cb.isNil:
        cb(line)
      line.add('\n')
      #echo "writing , " ,line
      await output.write(line)
      #echo "written?"

      #let bytesRead = await input.readBuffer(buffer, 1024)
      #if bytesRead == 0: break
      #await output.writeBuffer(buffer, bytesRead)

    await sleepAsync 1000

proc asyncPipe*(process: Process, dest: string, mode = fmAppend, cb: PipeCb = nil) {.async.} =
  var 
    #buffer : array[1024, char]
    buffer: string
    #input: File
  let
    output = openAsync(dest, mode)
  #discard input.open(process.outputHandle, fmRead)
    input = newAsyncFile(process.outputHandle.AsyncFd)

  #await pipeLoop(process, input, output, addr buffer#[, selector]#)
  await pipeLoop(process, input, output, buffer, cb#[, selector]#)
  #var selector = newSelector[cint]()
  #try:
  #  selector.registerHandle(int process.outputHandle, {Event.Read}, cint process.outputHandle)
  #  await pipeLoop(process, input, output, addr buffer, selector)
  #except:
  #  echo "couldn't register handle"
 
