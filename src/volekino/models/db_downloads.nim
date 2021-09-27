import db_sqlite, tables, uri,strutils, re, os
import db_jobs except createTable
import httpclient, asyncdispatch, asyncfile
import ../globals, ../uid
import ../../common/library_types
import transmission_remote
import json, cgi, times#[wtf]#

import util

const SQL_STATEMENTS = statementsFrom("./statements/downloads.sql")


type DownloadDb* = object
  db: DbConn
  jdb: JobsDb

converter toJobsDb(ddb: DownloadDb): JobsDb = ddb.jdb
proc createTable*(db: DbConn): DownloadDb =
  db.exec(sql SQL_STATEMENTS["create"])
  DownloadDb(db: db, jdb: db_jobs.createTable(db))


proc getDownloads*(ddb: DownloadDb): seq[Download] =
  let completedMaxAge = initDuration(hours=1)
  #echo "completedMaxAge = ", completedMaxAge
  for row in ddb.db.rows(sql SQL_STATEMENTS["get-all"], toUnix(now().toTime - completedMaxAge)):
    if row[0].len == 0: break
    try:
      result.add Download(
        id: parseInt row[0],
        resourceName: row[1],
        resourceType: DownloadResource(parseInt row[2]),
        url: row[3],
        progress: parseInt row[4],
        status: row[5]
        
      )
    except: echo getCurrentExceptionMsg() #discard

proc addDownload(ddb: DownloadDb, resourceName: string, resourceType: DownloadResource , url: string, torrentHandle = -1): int =
  let id = ddb.jdb.createJob()
  ddb.db.exec(sql SQL_STATEMENTS["add"], id, resourceName, ord resourceType, torrentHandle, url)
  id


        #addTorrent(resourceName=filename, resourceType=DownloadResource.Default, downloadUrl=url filename=url)
proc addTorrent(ddb: DownloadDb, resource, resourceName: string, resourceType: DownloadResource, downloadUrl: string): Future[int] {.async.} =
  let
    response = await transmission.addTorrent(resource)
    torrentHandle = response.id
    jobId = ddb.addDownload(resourceName=resourceName, resourceType=resourceType, url=downloadUrl, torrentHandle=torrentHandle)

  
  proc addTorrentInner {.async.} =
    while true:
      let response = await transmission.getTorrent(torrentHandle, Key.percentDone, Key.error, Key.errorString, Key.leftUntilDone)
      let progress = int(100 * response.percentDone)
      
      if response.leftUntilDone == 0 and progress > 0:
        ddb.updateJob(jobId, progress, "complete")
        break

      if response.error != 0:
        ddb.errorJob(jobId, error=response.errorString)
        break
        

      ddb.updateJob(jobId, progress)
      await sleepAsync(500)

  asyncCheck addTorrentInner()
  return jobId


proc createDownload*(ddb: DownloadDb, url: string): Future[int] {.async.} =
  let uri = parseUri url
  result = -1
  #echo uri.scheme
  if uri.scheme in ["http", "https"]:
    let 
      client = newAsyncHttpClient()
      dl = await client.get(url)
      contentType = dl.headers.getOrDefault("content-type")
      contentDisposition = dl.headers.getOrDefault("content-disposition")
      filenameRegex = re("filename=\"(.*)\"")
      indices = contentDisposition.findBounds(filenameRegex)
      filename = if indices[0] != -1:
        contentDisposition[indices[0] + 10..indices[1] - 1]
      else:
        let 
          extension = contentType.split('/')[1]
          pathTail = uri.path[uri.path.rfind('/')+1..^1]

        if not pathTail.endsWith(extension):
          pathTail & '.' & extension
        else:
          pathTail
    if contentType != "":
      echo contentType
      if contentType.startsWith("video/"):
        let 
          handle = openAsync(mediaDir / filename, fmWrite)
          jobId = ddb.addDownload(resourceName=filename, resourceType=DownloadResource.Default, url=url)

        result = jobId

        client.onProgressChanged = proc(total, progress, speed: BiggestInt) {.async, gcsafe.} = (
          let progress = progress * 100 div total
          ddb.updateJob(jobId, int progress)
        )

        #TODO this shouldn't be awaited
        let downloadFuture = handle.writeFromStream(dl.bodyStream)

        downloadFuture.callback = ( proc {.gcsafe.}= ddb.updateJob(jobId, 100, "complete") )


        echo "downloaded the video to ", filename
      elif contentType == "application/x-bittorrent":
        result = await ddb.addTorrent(resource=url, resourceName=filename, resourceType=DownloadResource.Default, downloadUrl=url)
      else:
        discard
        # report an error for this
        
    else:
      #report an error for this
      echo "no content type detected"
    echo dl.headers[]
  elif uri.scheme == "magnet":
    var dn = url
    for (key, value) in uri.query.decodeData:
      if key == "dn":
        dn = value

    result = await ddb.addTorrent(resource=url, resourceName=dn, resourceType=DownloadResource.Default, downloadUrl=url)

    echo "it's a magnet"
  else:
    echo "nope"
    


when isMainModule:
  # this is now untestable
  import ../daemons/transmissiond
  let tdprocess = startTransmissionD(nil)
  sleep(5000)
  initTransmissionRemote()
  let conn = open(tmpDir / "volekino.db", "", "", "")
  let ddb = createTable(conn)
  #waitFor ddb.createDownload(url="http://releases.ubuntu.com/14.04.1/ubuntu-14.04.1-desktop-amd64.iso.torrent")
  echo waitFor ddb.createDownload(url="magnet:?xt=urn:btih:6E003200502AA38668115E413BB0AD4DD79BD2FB&dn=Billions.S05E11.WEB.x264-TORRENTGALAXY&tr=udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce&tr=udp%3A%2F%2Ftracker.tiny-vps.com%3A6969%2Fannounce&tr=udp%3A%2F%2Ffasttracker.foreverpirates.co%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Fexplodie.org%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.cyberia.is%3A6969%2Fannounce&tr=udp%3A%2F%2Fipv4.tracker.harry.lu%3A80%2Fannounce&tr=udp%3A%2F%2Ftracker.uw0.xyz%3A6969%2Fannounce&tr=udp%3A%2F%2Fopentracker.i2p.rocks%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.birkenwald.de%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce&tr=udp%3A%2F%2Ftracker.moeking.me%3A6969%2Fannounce&tr=udp%3A%2F%2Fopentor.org%3A2710%2Fannounce&tr=udp%3A%2F%2Ftracker.dler.org%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.zer0day.to%3A1337%2Fannounce&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969%2Fannounce&tr=udp%3A%2F%2Fcoppersurfer.tk%3A6969%2Fannounce")
  shutdownTransmissionD(tdprocess)
  #waitFor addDownload("fuck", url="https://files.abreidenbach.com/public/VID_20210822_211105.mp4")
  #waitFor addDownload("shit", url="magnet:?xt=urn:btih:4C58CEB82E65FBBD9C1BFEB2C72F40C4DAC9F0E6&dn=Archer.2009.S12E06.1080p.WEB.H264-CAKES&tr=http%3A%2F%2Ftracker.trackerfix.com%3A80%2Fannounce&tr=udp%3A%2F%2F9.rarbg.me%3A2900%2Fannounce&tr=udp%3A%2F%2F9.rarbg.to%3A2970%2Fannounce&tr=udp%3A%2F%2Ftracker.slowcheetah.org%3A14800%2Fannounce&tr=udp%3A%2F%2Ftracker.tallpenguin.org%3A15710%2Fannounce&tr=udp%3A%2F%2Ftracker.zer0day.to%3A1337%2Fannounce&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969%2Fannounce&tr=udp%3A%2F%2Fcoppersurfer.tk%3A6969%2Fannounce")
  

