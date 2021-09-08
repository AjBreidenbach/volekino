#create
create table if not exists Subtitles (
  uid char(40) not null,
  lang char(3),
  title varchar(32),
  entryUid char(40) not null,
  primary key (uid, entryUid)
)

#get
select uid, lang, title from Subtitles where entryUid = ?

#add
insert into Subtitles (entryUid, uid, lang, title) values (?, ?, ?, ?)

#remove-by-entry
delete from Subtitles where entryUid = ? returning uid

#inner-join-entry-count
select COUNT(*) from Subtitles inner join Entries on Subtitles.entryUid = Entries.uid where Subtitles.uid = ?

#entry-track-exists
select COUNT(*) from Subtitles where entryUid = ? and lang = ? and title = ?

#track-exists
select COUNT(*) from Subtitles where lang = ? and title = ?

#get-subtitles
select uid from Subtitles where entryUid = ?

#share-subtitles
insert into Subtitles
select uid, lang, title, ? from Subtitles
where entryUid = ?

#add-to-path
insert into Subtitles
select ?, ?, ?, uid from Entries
where path like ?

#debug-select
select ?, ?, ?, uid from Entries
where path like ?


