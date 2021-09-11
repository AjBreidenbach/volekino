#create
create table if not exists OTPAuthn (
  userId integer not null primary key,
  allowAccountCreation boolean,
  otp char(28),
  ts integer(4) not null default (strftime('%s','now'))
)

#add
insert into OTPAuthn (userId, allowAccountCreation, otp) values (?, ?, ?)


#get-user
select userId from OTPAuthn where otp = ?

#delete
delete from OTPAuthn where otp = ?

#allows-account-creation
select allowAccountCreation from OTPAuthn where otp = ?

