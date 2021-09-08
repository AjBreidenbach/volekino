#add
insert into Entries (path, uid, videoEncoding, audioEncoding, duration) values (?, ?, ?, ?, ?)

#create
create table if not exists Entries (
  uid char(40) not null primary key,
  path text,
  videoEncoding varchar(16),
  audioEncoding varchar(16),
  duration integer
);

#getall
select * from Entries

#hasentry
select COUNT(uid) == 1 from Entries where path=?

#hasuid
select COUNT(uid) == 1 from Entries where uid=?

#remove
delete from Entries where uid = ?

#get-entry
select * from Entries where uid = ?

#get-entry-uid
select uid from Entries where path = ?
