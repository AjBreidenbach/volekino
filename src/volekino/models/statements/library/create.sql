create table if not exists Entries (
  id integer not null primary key autoincrement,
  path text,
  videoEncoding varchar(16),
  audioEncoding varchar(16)
);

