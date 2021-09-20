when defined(js):
  import jsffi
  type StringImpl* = cstring
  type Dynamic* = JsObject
else:
  import json
  type StringImpl* = string
  type Dynamic* = JsonNode

type User* = ref object 
  id*: int
  username*: StringImpl
  isAdmin*: bool
  authMethod*: int

proc isRegistered*(user: User): bool =
  user.authMethod == 0

type ApplySettingsFragment* = ref object
  key*, value*: StringImpl

type ApplySettingsRequest* = seq[ApplySettingsFragment]
  


type AppSetting* = ref object
  name*: StringImpl
  default*: Dynamic
  value*: Dynamic
  description*: StringImpl
  selector*: StringImpl
  requiresRestart*: bool

type CreateUserRequest* = object
  isAdmin*, allowAccountCreation*: bool 
