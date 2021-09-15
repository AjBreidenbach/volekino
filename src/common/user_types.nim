when defined(js):
  type StringImpl* = cstring
else:
  type StringImpl* = string

type User* = ref object 
  id*: int
  username*: StringImpl
  isAdmin*: bool
  authMethod*: int

proc isRegistered*(user: User): bool =
  user.authMethod == 0
