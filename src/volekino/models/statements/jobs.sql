#create
create table if not exists Jobs(
  id integer not null primary key autoincrement,
  progress integer,
  status varchar(32),
  ts integer(4) not null default (strftime('%s','now')),
  data text
)

#create-job
insert into Jobs (progress, status) values (0, "started")

#update-job
update Jobs
set progress = ?, status = ?
where id = ?

#data
update Jobs
set progress = -1, status = ?, data = ?
where id = ?

#job-status
select status, progress, data from Jobs where id = ?
