#create
create table if not exists Thumbnails (
  id integer not null primary key,
  uid char(40)
)

#get
select uid from Thumbnails where id = ?

#add
insert into Thumbnails (id, uid) values (?, ?)

#remove
delete from Thumbnails where id = ? returning uid
