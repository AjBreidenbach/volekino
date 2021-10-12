import mithril, mithril/common_selectors
import ./jsffi, ./globals


var Login* = MComponent()

type LoginState = ref object
  loginField, passwordField, otpField: JsObject
  errorMessage: cstring


Login.oncreate = lifecycleHook:
  state.loginField = vnode.dom.querySelector(cstring"input[type='text']")
  state.passwordField = vnode.dom.querySelector(cstring"input[type='password']")
  state.otpField = vnode.dom.querySelector(cstring("input[name='otp']"))
  state.errorMessage = cstring""

Login.view = viewFn(LoginState):
  let handleLogin = eventHandlerAsync:
    e.preventDefault()

    var requestBody = newJsObject()
    if state.loginField.value.to(bool):
      requestBody.username = state.loginField.value
      requestBody.password = state.passwordField.value
    else:
      requestBody.password = state.otpField.value

    try:
      let response = await mrequest(apiPrefix"login", Post, requestBody)
      state.errorMessage = ""

      discard setTimeout(
        cint 100,
        TimeoutFunction(
          proc(): void = mrouteset("/")
        )
      )

    except:
      let response = getJsException().response
      state.errorMessage = response.error.to(cstring)
    
  mdiv(
    a {class: "form-wrapper"},
    

    mdiv(
      a {class: "login-form"},
      mh2("Login"),
      mform(
        mh5("Enter your login and password"),
        minput(a {placeholder: "Login", type: "text"}),
        minput(a {placeholder: "Password", type: "password"}),

        mcenter(
          a {style: "text-decoration-line: underline; "},
          "or"
        ),

        mh5("Use a one-time password"),
        minput(a {tabindex: -1, placeholder: "OTP Login", name: "otp", type: "text"}),
        minput(a {style: "margin: 1em auto; width: 175px", onclick: handleLogin, type: "submit", value: "Login"})
      ),
      mcenter(
        a {style: "min-height: 2em"},
        state.errorMessage
      )

    )

  )
  


var Registration* = MComponent()

type RegistrationState = ref object
  usernameField, passwordField: JsObject
  errorMessage: cstring


Registration.oncreate = lifecycleHook:
  state.usernameField = vnode.dom.querySelector(cstring"input[type='text']")
  state.passwordField = vnode.dom.querySelector(cstring"input[type='password']")

Registration.view = viewFn(RegistrationState):
  let handleRegistration = eventHandlerAsync:
    e.preventDefault()

    var requestBody = newJsObject()
    requestBody.username = state.usernameField.value
    requestBody.password = state.passwordField.value

    try:
      let response = await mrequest(apiPrefix"register", Post, requestBody)
      state.errorMessage = "registration successful..."

      discard setTimeout(
        cint 500,
        TimeoutFunction(
          proc(): void = mrouteset("/")
        )
      )
    except:
      let response = getJsException().response
      state.errorMessage = response.error.to(cstring)
    
  mdiv(
    a {class: "form-wrapper"},
    mdiv(a {class: "login-form"},
      mh2("Register"),
      mform(
        mh5("Enter desired username and password"),
        #mlabel(
        #  "Desired username",
        minput(a {placeholder: "Username", type: "text"}),
        #),
        #mlabel(
        #  "Password",
        minput(a {placeholder: "Password", type: "password"}),
        #),
        minput(a {onclick: handleRegistration, type: "submit", value: "Register", style: "margin: 1em auto; width: 175px"})
      ),

      mcenter(
        a {style: "min-height: 2em"},
        state.errorMessage
      )
    )


  )
  
