#get
select value from AppSettings where key = ?

#getall
select key, value from AppSettings

#set
insert or replace into AppSettings (key, value) values (?, ?)

#create
create table if not exists AppSettings (
  key varchar(32) not null,
  value varchar(32),
  primary key (key)
)
