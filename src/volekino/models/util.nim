import tables, strutils
export tables

func processStatements(statements: string): Table[string,string] =
  let statements = statements.split('#')
  for statement in statements:
    let splits = statement.split('\n', maxsplit=1)
    if splits.len < 2:
      continue
    let name = splits[0]
    let body = splits[1]
    result[name] = body
  


template statementsFrom*(f: string): Table[string, string] =
  bind processStatements
  processStatements(slurp(f))

