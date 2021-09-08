#create
create table if not exists Jobs(
  id integer not null primary key autoincrement,
  progress integer,
  status varchar(32)
)

#create-job
insert into Jobs (progress, status) values (0, "started")

#update-job
update Jobs
set progress = ?, status = ?
where id = ?

#job-status
select status, progress from Jobs where id = ?
