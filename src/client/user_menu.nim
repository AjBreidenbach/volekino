import jsffi, mithril, mithril/common_selectors
import ../common/user_types
from sugar import capture



const LOGGED_OUT = cstring"not logged in"
const PLAIN_USER = cstring"logged in"
const AS_ADMIN = cstring"logged in as admin"

type SettingsManagerState = ref object
  ready: bool
  settings: seq[AppSetting]
  initialSettings: cstring
  request: ApplySettingsRequest

var SettingsManager = MComponent()

proc refreshSettings(state: var SettingsManagerState) {.async.} =
  let response = await mrequest("/api/settings")
  state.settings = response.to(seq[AppSetting])
  state.initialSettings = JSON.stringify(response).to(cstring)
  state.request = @[]

  state.ready = true

SettingsManager.oninit = lifecycleHook(SettingsManagerState):
  state.ready = false
  #state.request = @[]
  await state.refreshSettings()
    
SettingsManager.view = viewFn(SettingsManagerState):
  let commitChanges = eventHandlerAsync:
    try:
      let response = await mrequest("/api/settings", Post, toJs state.request)
    except:
      console.log getJsException

    await state.refreshSettings()

  let clear = eventHandler:
    discard state.refreshSettings()
    
  if state.ready:
    mchildren(
      mtable(
        a {class: "admin-settings"},
        mtr(mth"Setting", mth"Description",  mth"Default", mth"Value"),
        mchildren(
        block:
          var nodes = newSeq[VNode]()
          for setting in state.settings:
            closureScope:
              let setting = setting
              let onchange = eventHandler:
                #e.redraw = false
                let newValue = cstring"" & (
                  if e.target["type"].to(cstring) == cstring"checkbox":
                    e.target.checked.to(cstring)
                  else:
                    e.target.value.to(cstring)
                )

                try:
                  setting.value = JSON.parse newValue
                except:
                  setting.value = toJs newValue

                var found = false
                for fragment in state.request.mitems:
                  if fragment.key == setting.name:
                    found = true
                    fragment.value = newValue
                if not found:
                  state.request.add ApplySettingsFragment(key: setting.name, value: newValue)


              nodes.add mtr(
                mtd(a {style: "font-family: monospace; white-space: nowrap;"}, setting.name),
                mtd(a {style: "font-size: 0.9em;"}, setting.description),
                mtd(a {style: "font-family: monospace;"},setting.default),
                mtd(
                  m(toSelector $setting.selector, a {value: setting.value, checked: isTruthy(setting.value), onchange: onchange})
                )
              )
          nodes
        )
      ),
      if state.initialSettings != JSON.stringify(state.settings).to(cstring):
        mdiv(
          a {style: "display: flex; justify-content: space-between"},
          mbutton(a {onclick: commitChanges}, "Commit changes"),
          mbutton(a {onclick: clear}, "Clear")
        )
      else: nil
    )
  else: nil

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
    m(OTPUserGenerator),
    m(SettingsManager)
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
    a {class: "spacer", style: "margin: 1em"},
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
