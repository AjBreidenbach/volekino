import mithril, mithril/common_selectors
import ./tab_select, ./globals, ./jsffi


var LogView* = MComponent()

type LogViewState = ref object
  currentTab: cstring
  logText: cstring

proc refresh(state: var LogViewState) {.async.}=
  let response = await mrequest(apiPrefix"logs" & cstring"/" & state.currentTab)
  state.logText = response.contents.to(cstring)

LogView.oninit = lifecycleHook(LogViewState):
  state.currentTab = cstring"volekino"
  discard state.refresh()

LogView.view = viewFn(LogViewState):
  proc cb(selection: cstring) =
    state.currentTab = selection
    discard state.refresh()

  mdiv(
    a {class: "spacer", style: "max-width: 1200px; margin: 1em auto"},
    mdiv(
      a {style:"position: sticky; top: 0; background-color: white;"},
      m(TabSelect, a {callback: cb, selections: @[cstring"volekino", cstring"apache", cstring"transmission", cstring"ssh"]})),
    mdiv(
      a {class: "log"},
      state.logText
    )
  )
