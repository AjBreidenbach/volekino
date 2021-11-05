import mithril, mithril/common_selectors
import ./tab_select, ./globals, ./jsffi


var LogView* = MComponent()
proc mtrust(s:cstring): VNode {.importc: "m.trust".}

type LogViewState = ref object
  currentTab: cstring
  logText: cstring

proc refresh(state: var LogViewState) {.async.}=
  let response = await mrequest(apiPrefix"logs" & cstring"/" & state.currentTab)
  state.logText = response.contents.to(cstring)

LogView.oninit = lifecycleHook(LogViewState):
  state.currentTab = cstring"software credits"
  discard state.refresh()

LogView.view = viewFn(LogViewState):
  proc cb(selection: cstring) =
    state.currentTab = selection
    discard state.refresh()

  mdiv(
    a {class: "spacer", style: "width: min(1200px, 100%); margin: 1em auto; overflow: auto"},
    mdiv(
      a {style:"position: sticky; top: 0; background-color: white;"},
      m(TabSelect, a {callback: cb, selections: @[cstring"software credits", cstring"volekino", cstring"apache", cstring"transmission", cstring"ssh"]})),
    mdiv(
      a {class: "log"},
      if state.currentTab == cstring"software credits":
        mtrust(state.logText)
      else:
        state.logText
    )
  )
