#create
create table if not exists Downloads (
  jobId integer, --not null primary key,
  resourceName text,
  resourceType integer, -- tar, gzip, etc 
  torrentHandle integer, -- transmission torrent handle
  url text primary key
)

#add
replace into Downloads (jobId, resourceName, resourceType, torrentHandle, url) values (?,?,?,?,?)

#get-all
select jobId, resourceName, resourceType, url, progress, status from Downloads inner join Jobs on jobId = id where status != "complete" or ts > ?
