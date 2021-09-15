import db_sqlite, tables

type AppSettings* = distinct DbConn

proc createTable*(db: DbConn): AppSettings =
  const statement = slurp("./statements/appsettings/create.sql")
  db.exec(sql statement)
  AppSettings(db)



proc setProperty*(db: AppSettings, key: string, value: string = "") =
  const statement = slurp("./statements/appsettings/set.sql")
  DbConn(db).exec(sql statement, key, value)


import strformat
proc getProperty*(db: AppSettings, key: string): string =
  const statement = slurp("./statements/appsettings/get.sql")
  result = DbConn(db).getValue(sql statement, key)
  echo &"get ({key}) = {result}"


proc getAllProperties*(db: AppSettings): TableRef[string,string]=
  const statement = slurp("./statements/appsettings/getall.sql")
  result = newTable[string,string]()
  for row in DbConn(db).getAllRows(sql statement):
    let key = row[0]
    let value = row[1]
    result[key] = value
    
 
