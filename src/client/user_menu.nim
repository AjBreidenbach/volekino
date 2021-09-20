import jsffi, mithril, mithril/common_selectors
import ../common/user_types



const LOGGED_OUT = cstring"not logged in"
const PLAIN_USER = cstring"logged in"
const AS_ADMIN = cstring"logged in as admin"

type OTPUserGeneratorState = ref object
  allowAccountCreation, isAdmin: bool
  copyElement: JsObject
  statusMessage: cstring
  isError: bool

var OTPUserGenerator = MComponent()

OTPUserGenerator.oninit = lifecycleHook(OTPUserGeneratorState):
  state.allowAccountCreation = true
  state.isAdmin = false

OTPUserGenerator.oncreate = lifecycleHook(OTPUserGeneratorState):
  state.copyElement = vnode.dom.querySelector(".copyElement")
  #console.log(state.copyElement)

proc setClipboard(state: OTPUserGeneratorState, value: cstring) =
  #console.log(state)
  state.copyElement.value = value
  state.copyElement.select()
  state.copyElement.setSelectionRange(0, 99999)
  navigator.clipboard.writeText(state.copyElement.value)

proc setStatus(state: var OTPUserGeneratorState, message: cstring, isError=false) =
  state.statusMessage = message
  state.isError = isError
  if not isError:
    discard setTimeout(
      cint 5000,
      proc =
        state.statusMessage = cstring""
        mredraw()
      
    )
proc setErrorStatus(state: var OTPUserGeneratorState, message: cstring) =
  state.setStatus(message, true)
  
OTPUserGenerator.view = viewFn(OTPUserGeneratorState):
  let onclickAccountCreation = eventHandler:
    state.allowAccountCreation = e.target.checked.to(bool)

  let onclickAdminPrivileges = eventHandler:
    state.isAdmin = e.target.checked.to(bool)

  let onclickCopy = eventHandlerAsync:
    e.preventDefault()
    let requestBody = toJs CreateUserRequest(isAdmin: state.isAdmin, allowAccountCreation: state.allowAccountCreation)
    #console.log cstring"requestBody = ", requestBody
    try:
      let response = await mrequest("/api/users/", Post, requestBody)
      let uid = response.uid.to(cstring)
      state.setClipboard(uid)
      state.setStatus cstring"Copied one-time password to clipboard"
    except:
      state.setErrorStatus getJsException().to(cstring)
    
  mdiv(
    a {style: "width: 400px;"},
    mh6("User creation"),

    mform(
      a {style: "position: relative"},
      mlabel(
        "Allow account creation",
        minput(a {type: "checkbox", onclick: onclickAccountCreation, checked: "true"})
      ),
      mlabel(
        "Grant admin privileges",
        minput(a {type: "checkbox", onclick: onclickAdminPrivileges})
      ),
      minput(a {class: "copyElement", style: "opacity:0; position:absolute"}),
      minput(
        a {type: "submit", value: "Create user", onclick: onclickCopy}
      )
    ),
    mspan(a {style: if state.isError: "color: red;" else: ""}, state.statusMessage)

  )


type AdminPanelState = ref object

var AdminPanel = MComponent()

AdminPanel.view = viewFn(AdminPanelState):
  mdiv(
    a {style: "margin: 2em 1em;"},
    mh5("Admin panel"),
    m(OTPUserGenerator)
  )

type UserMenuState = ref object
  loginStatus: cstring
  authMethod: int
  ready: bool

proc isRegistered(state: UserMenuState): bool  =
  result = state.authMethod == 0
  #echo "#isRegistered ", result
  
proc canRegister(state: UserMenuState): bool =
  result = state.authMethod == 3


proc isLoggedIn(state: UserMenuState): bool =
  #console.log cstring "loginStatus",  state.loginStatus
  state.loginStatus != LOGGED_OUT



proc isAdmin(state: UserMenuState): bool =
  state.loginStatus == AS_ADMIN


var UserMenu* = MComponent()

UserMenu.oninit = lifecycleHook(UserMenuState):

  var loginStatus = LOGGED_OUT
  var authMethod = 0

  
  try:
    let response = await mrequest("/api/users/me")
    if isTruthy response.isAdmin:
      loginStatus = AS_ADMIN
    else:
      loginStatus = PLAIN_USER

    if isTruthy response.authMethod:
      authMethod = response.authMethod.to(int)

  except: discard
      

  #state = UserMenuState(loginStatus: loginStatus, authMethod: authMethod, ready: true)
  state.loginStatus = loginStatus
  state.authMethod = authMethod

  state.ready=true
  

UserMenu.view = viewFn(UserMenuState):
  let onclickLogout = eventHandlerAsync:
    e.preventDefault()
    discard await mrequest("/api/logout", Post)
    mrouteset(getPath())

  mdiv(
    a {style: "margin: 1em"},
    mul(
      a {style: "font-size: 1.2em"}, 
      block login:
        if state.isLoggedIn:
          mli ma(
            a {href: "#", onclick: onclickLogout}, "Logout"
          )
        else:
          mli m(mrouteLink,
            a {href: "/login"}, "Login"
          )
      ,
      block register:
        if state.isRegistered or not state.canRegister:
          nil
        else:
          mli m(mrouteLink,
            a {href: "/register"}, "Register"
          )
    ),
    block admin:
      if state.isAdmin:
        m(AdminPanel)
      else:
        nil
  )
