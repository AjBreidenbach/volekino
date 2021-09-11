#create
create table if not exists BasicAuthn (
  userId integer not null primary key,
  pwhash char(172),
  salt char(88)
)

#add
insert into BasicAuthn (userId, pwhash, salt) values (?, ?, ?)

#get
select BasicAuthn.userId, pwhash, salt from BasicAuthn inner join Users on Users.userId = BasicAuthn.userId where username = ?
