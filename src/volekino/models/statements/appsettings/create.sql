create table if not exists AppSettings (
  key varchar(32) not null,
  value varchar(32),
  primary key (key)
)
