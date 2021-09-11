#create
create table if not exists Sessions(
  sessionToken char(28) not null primary key,
  userId integer,
  allowAccountCreation boolean,
  ts integer(4) not null default (strftime('%s','now'))
)

#add
insert into Sessions (sessionToken, userId, allowAccountCreation) values (?, ?, ?)

#get
select Users.userId, isAdmin, allowAccountCreation, ts from Sessions inner join Users on Users.userId = Sessions.userId where sessionToken = ?
