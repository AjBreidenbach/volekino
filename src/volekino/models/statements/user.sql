#create
create table if not exists Users (
  userId integer not null primary key autoincrement,
  username text,
  isAdmin boolean,
  authMethod integer -- 0: basic, 1: otp
)

#add
insert into Users (username, isAdmin, authMethod) values (?, ?, ?)

