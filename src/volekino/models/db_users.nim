import util, db_sqlite, strutils, sqlite3
import ../uid
import nimcrypto, nimcrypto/[pbkdf2]
import ../../common/user_types
from base64 import nil
import times

const USER_STATEMENTS = statementsFrom("./statements/user.sql")
const SESSION_STATEMENTS = statementsFrom("./statements/session.sql")
const BASICAUTHN_STATEMENTS = statementsFrom("./statements/basicauthn.sql")
const OTPAUTHN_STATEMENTS = statementsFrom("./statements/otpauthn.sql")

type UsersDb* = distinct DbConn

converter toUser(row: Row): User =
  result = User()
  try: result.id = parseInt row[0]
  except: result.id = -1; return

  result.username = row[1]
  result.isAdmin = parseBool row[2]
  result.authMethod = parseInt row[3]
  

proc getUser*(udb: UsersDb, userId: int | int64): User =
  let db = DbConn(udb)
  toUser db.getRow(sql USER_STATEMENTS["get"], userId)

proc getAllUsers*(udb: UsersDb): seq[User] =
  let db = DbConn(udb)
  for row in db.rows(sql USER_STATEMENTS["getall"]):
    result.add(toUser row)

proc createUserTables*(db: DbConn): UsersDb =
  db.exec(sql USER_STATEMENTS["create"])
  db.exec(sql SESSION_STATEMENTS["create"])
  db.exec(sql BASICAUTHN_STATEMENTS["create"])
  db.exec(sql OTPAUTHN_STATEMENTS["create"])
  UsersDb(db)


type AuthMethod = distinct string

const BASIC_AUTH* = AuthMethod"0"
const OTP_AUTH* = AuthMethod"1"
const OTP_AUTH_REGISTRATION_ALLOWED* = AuthMethod"3"

proc registeredCount*(udb: UsersDb): int =
  let db = DbConn(udb)
  try:
    parseInt db.getValue(sql USER_STATEMENTS["registered-count"])
  except: 0


proc addUser(udb: UsersDb, username = "", authMethod: AuthMethod = BASIC_AUTH, isAdmin=false): int64 =
  let db = DbConn(udb)
  db.exec(sql USER_STATEMENTS["add"], username, isAdmin, string authMethod)
  db.last_insert_row_id

proc addOtpAuthn(udb: UsersDb, userId: int64, allowAccountCreation= false, otp: string) =
  let db = DbConn(udb)
  db.exec(sql OTPAUTHN_STATEMENTS["add"], userId, allowAccountCreation, otp)

proc addBasicAuthn(udb: UsersDb, userId: int64, pwhash, salt: string) =
  let db = DbConn(udb)
  db.exec(sql BASICAUTHN_STATEMENTS["add"], userId, pwhash, salt)


proc createOtpUser*(udb: UsersDb, allowAccountCreation=false, isAdmin=false): string =
  #let db = DbConn(udb)
  let userId = udb.addUser(
    "",
    if allowAccountCreation: OTP_AUTH_REGISTRATION_ALLOWED else: OTP_AUTH,
    isAdmin=isAdmin
  )
  result = genUidB64()
  udb.addOtpAuthn(userId, allowAccountCreation=allowAccountCreation, otp=result)

type Salt = openarray[uint8]

proc computePasswordHash(password: openarray[char], salt: Salt): string =
  base64.encode(
    pbkdf2(sha256, password, salt, 10000, 128)
  )

proc computePasswordHash(password: openarray[char], salt: string): string =
  base64.encode(
    pbkdf2(sha256, password, base64.decode(salt), 10000, 128)
  )
  

proc createUser*(udb: UsersDb, username, password: string, isAdmin=false): int64 =
  var salt: array[64, uint8]
  discard randomBytes(salt)

  let userId = udb.addUser(username, authMethod=BASIC_AUTH, isAdmin=isAdmin)


  let pwhash = computePasswordHash(password,salt)

  let saltEncoded = base64.encode(salt)

  udb.addBasicAuthn(userId, pwhash, saltEncoded)
  #let pwhashEncoded = base64.encode(pwhash)

  return userId
  #assert computePasswordHash(password, salt) == computePasswordHash(password, saltEncoded)

proc createSession(udb: UsersDb, userId: int64, allowAccountCreation: bool=false): string =
  let db = DbConn(udb)
  result = if userId == -1: "" else:  genUidB64()
  db.exec(sql SESSION_STATEMENTS["add"], result, userId, allowAccountCreation)

proc getUserFromOTP(udb: UsersDb, otp: string): int64 =
  let db = DbConn(udb)
  try:
    parseInt db.getValue(sql OTPAUTHN_STATEMENTS["get-user"], otp)
  except: -1

proc allowsAccountCreation(udb: UsersDb, otp: string): bool =
  #echo "user"
  let db = DbConn(udb)
  try:
    let value = db.getValue(sql OTPAUTHN_STATEMENTS["allows-account-creation"], otp)
    #echo "value = ", value
    result = parseBool value


    #echo "allowsAccountCreation ", result

  except:
    #echo getCurrentExceptionMsg()
    result = false


proc otpCreationTime(udb: UsersDb, otp: string): int =
  let db = DbConn(udb)
  try:
    let value = db.getValue(sql OTPAUTHN_STATEMENTS["ts"], otp)
    parseInt value
  except: 0


proc otpLogin*(udb: UsersDb, otp: string, expirationPeriod: int): string =
  #TODO check if otp is expired
  let ts = udb.otpCreationTime(otp)
  let currentTime = toUnix getTime()

  if ts + expirationPeriod < currentTime: return

  result = udb.createSession(
    udb.getUserFromOTP(otp),
    allowAccountCreation=udb.allowsAccountCreation(otp)
  )

  let db = DbConn(udb)

  db.exec(sql OTPAUTHN_STATEMENTS["delete"], otp)

proc basicLogin*(udb: UsersDb, username: string, password: string): string =
  let db = DbConn(udb)

  let userRecord = db.getRow(sql BASICAUTHN_STATEMENTS["get"], username)
  if userRecord[0] == "": return

  let userId = parseInt userRecord[0]
  let pwhash = userRecord[1]
  let salt = userRecord[2]


  if computePasswordHash(password, salt) == pwhash:
    udb.createSession(userId)
  else: ""

type SessionStateKind* {.pure.} = enum
  None,
  LoggedIn,
  Admin

type SessionState* = ref object
  case kind: SessionStateKind
  of SessionStateKind.LoggedIn, SessionStateKind.Admin:
    userId: int64
    allowAccountCreation: bool
  else: discard


proc isLoggedIn*(sessionState: SessionState): bool = sessionState.kind != SessionStateKind.None
proc isAdmin*(sessionState: SessionState): bool = sessionState.kind == SessionStateKind.Admin

proc getUser*(udb: UsersDb, sessionState: SessionState): User =
  try:
    udb.getUser(sessionState.userId)
  except:
    User(id: -1)

proc sessionAuthorizationState*(udb: UsersDb, sessionToken: string, expirationPeriod: int): SessionState =
  let db = DbConn(udb)

  let row = db.getRow(sql SESSION_STATEMENTS["get"], sessionToken)

  if row[0].len == 0:
    return SessionState(kind: SessionStateKind.None)

  let ts = try: parseInt row[3] except: 0
  let currentTime = toUnix getTime()

  if ts + expirationPeriod < currentTime:
    return SessionState(kind: SessionStateKind.None)

  let kind = if parseBool row[1]: SessionStateKind.Admin else: SessionStateKind.LoggedIn
  result = SessionState(kind: kind)

  result.userId = parseInt row[0]
  result.allowAccountCreation = parseBool row[2]
  


#proc updateCredentials(udb: UsersDb, userId: int64, )

proc registerOtpUser*(udb: UsersDb, sessionToken, username, password: string, expirationPeriod: int): string =
  let sessionState = udb.sessionAuthorizationState(sessionToken, expirationPeriod)
  if sessionState.allowAccountCreation:
    let userId = udb.createUser(username, password, isAdmin=sessionState.isAdmin)
    result = udb.createSession(userId)
    

let EMPTY_SESSION* = SessionState(kind: SessionStateKind.None)

  
when isMainModule:
  import ../globals, os
  removeFile(tmpDir / "test.db")
  let db = open(tmpDir / "test.db", "", "", "")
  let udb = createUserTables(db)
  block:
    discard udb.createUser("andrew", "hello")
    #echo udb.basicLogin("andrew", "hello")
    assert udb.basicLogin("andrew", "hello").len > 0
    assert udb.basicLogin("andrew", "goodbye") == ""

  block:
    let otp = udb.createOtpUser(allowAccountCreation=true)
    let session = udb.otpLogin(otp)
    assert session.len > 0
    assert udb.otpLogin(otp) == ""
    discard udb.registerOtpUser(session, "bob", "12345")
    assert udb.basicLogin("bob", "12345").len > 0
    assert udb.basicLogin("bob", "1234") == ""



