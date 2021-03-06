import jsffi, mithril, mithril/common_selectors
import ../common/user_types
import ./globals, ./settings_view, ./util
from sugar import capture



const LOGGED_OUT = cstring"not logged in"
const PLAIN_USER = cstring"logged in"
const AS_ADMIN = cstring"logged in as admin"

#[
type AppSettingData = ref object of AppSetting
  updatedValue: JsObject

type SettingsManagerState = ref object
  ready: bool
  settings: seq[AppSettingData]
  allowRedraw: bool
  requiresRestart: bool
  uncommittedChanges: bool

var SettingsManager = MComponent()

proc refreshSettings(state: var SettingsManagerState) {.async.} =
  console.log(cstring"refreshSettings", state)
  state.uncommittedChanges = false
  state.requiresRestart = false
  let response = await mrequest(apiPrefix"settings")
  state.settings = response.to(seq[AppSettingData])
  for i in 0..<state.settings.len:
    state.settings[i].updatedValue = state.settings[i].value
    
  state.ready = true

proc diffSettings(state: var SettingsManagerState) =
  var uncommittedChanges = false
  for setting in state.settings:
    if setting.updatedValue != setting.value:
      state.uncommittedChanges = true
      uncommittedChanges = true
      if setting.requiresRestart:
        state.requiresRestart = true
        return

  state.requiresRestart = false
  state.uncommittedChanges = uncommittedChanges

SettingsManager.oninit = lifecycleHook(SettingsManagerState):
  state.ready = false
  #state.request = @[]
  await state.refreshSettings()

SettingsManager.onbeforeupdate = beforeUpdateHook:
  result = old.state.allowRedraw.to(bool)
  vnode.state.allowRedraw = false
  

   
SettingsManager.view = viewFn(SettingsManagerState):
  let commitChanges = eventHandlerAsync:
    e.redraw = false
    try:
      var request: ApplySettingsRequest
      for setting in state.settings:
        if setting.value != setting.updatedValue:
          request.add ApplySettingsFragment(key: setting.name, value: setting.updatedValue.toString().to(cstring))
      state.allowRedraw=true
      let response = await mrequest(apiPrefix"settings", Post, toJs request)
    except:
      console.log getJsException
      echo "fuck"
    finally:
        discard reload()

    state.allowRedraw = true
    await state.refreshSettings()

  let clear = eventHandler:
    e.redraw = false
    state.allowRedraw = true
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
                state.allowRedraw = true
                #e.redraw = false
                let newValue = cstring"" & (
                  if e.target["type"].to(cstring) == cstring"checkbox":
                    e.target.checked.to(cstring)
                  else:
                    e.target.value.to(cstring)
                )

                try:
                  setting.updatedValue = JSON.parse newValue
                except:
                  setting.updatedValue = toJs newValue

                state.diffSettings()

              nodes.add mtr(
                mtd(a {style: "font-family: monospace; white-space: nowrap;"}, setting.name),
                mtd(a {style: "font-size: 0.9em;"}, setting.description),
                mtd(a {style: "font-family: monospace;"},setting.default),
                mtd(
                  m(toSelector $setting.selector, a {value: setting.updatedValue, checked: isTruthy(setting.updatedValue), onchange: onchange})
                )
              )
          nodes
        )
      ),
      if state.uncommittedChanges:
        mdiv(
          a {style: "display: flex; justify-content: space-between"},
          mbutton(a {onclick: commitChanges}, if state.requiresRestart: "Commit changes and restart" else: "Commit changes"),
          mbutton(a {onclick: clear}, "Clear")
        )
      else: mchildren()
    )
  else: mchildren()
]#
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

proc setStatus(state: var OTPUserGeneratorState, message: cstring, timeout=cint 5000, isError=false) =
  state.statusMessage = message
  state.isError = isError
  if not isError:
    discard setTimeout(
      timeout,
      proc =
        state.statusMessage = cstring""
        mredraw()
      
    )

proc setErrorStatus(state: var OTPUserGeneratorState, message: cstring) =
  state.setStatus(message, isError=true)
 
proc setClipboard(state: var OTPUserGeneratorState, value: cstring) =
  #console.log(state)
  if isTruthy navigator.clipboard:
    state.copyElement.value = value
    state.copyElement.select()
    state.copyElement.setSelectionRange(0, 99999)
    navigator.clipboard.writeText(state.copyElement.value)
    state.setStatus cstring"Copied one-time password to clipboard"
  else:
    state.setStatus cstring"OTP is " & value, timeout=30000
    

 
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
      let response = await mrequest(apiPrefix"users/", Post, requestBody)
      let uid = response.uid.to(cstring)
      state.setClipboard(uid)
      #state.setStatus cstring"Copied one-time password to clipboard"
    except:
      state.setErrorStatus getJsException().to(cstring)
    
  mdiv(
    a {style: "width: 400px; margin: 2em 0;"},
    mh6(a {style: "font-size: 1em; display: flex; justify-content: center; align-items: center;1em"}, "User creation", mimg(a {src: staticResource"/images/adduser.svg"})),

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
    mspan(a {class: "selectable", style: if state.isError: "color: red;" else: ""}, state.statusMessage)

  )


type AdminPanelState = ref object

var AdminPanel = MComponent()

AdminPanel.view = viewFn(AdminPanelState):
  mdiv(
    a {style: "margin: 2em 1em;"},
    mh5(a {style: "font-size: 1.2em"}, "Admin panel"),
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

  #var loginStatus = LOGGED_OUT
  #var authMethod = 0

  
  #[
  try:
    let response = await mrequest(apiPrefix"users/me")
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
  ]#

  state.ready=true
  

UserMenu.view = viewFn(UserMenuState):
  #[
  let onclickLogout = eventHandler:
    e.preventDefault()
    discard logout()
  ]#

  mdiv(
    a {class: "spacer", style: "margin: 1em auto; max-width: 1200px"},
    mul(
      a {style: "font-size: 1.2em"},

      #[
      block login:
        #if state.isLoggedIn:
        if isLoggedIn():
          mli ma(
            a {href: "#", onclick: onclickLogout}, "Logout"
          )
        else:
          mli m(mrouteLink,
            a {href: "/login"}, "Login"
          )

      ,
      ]#
      block register:
        #if state.isRegistered or not state.canRegister:
        if isRegistered() or not canRegister():
          mchildren()
        else:
          mli m(mrouteLink,
            a {href: "/register"}, "Register"
          )
    ),
    block admin:
      if isAdmin():
      #if state.isAdmin:
        m(AdminPanel)
      else:
        mchildren()
  )
