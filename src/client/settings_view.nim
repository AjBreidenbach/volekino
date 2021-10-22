import jsffi, mithril, mithril/common_selectors
import ./globals, ./util, ./tab_select
import ../common/user_types
type AppSettingData = ref object of AppSetting
  updatedValue: JsObject

type SettingsManagerState = ref object
  ready: bool
  settings: seq[AppSettingData]
  allowRedraw: bool
  requiresRestart: bool
  uncommittedChanges: bool
  showingCateogry: cstring

var SettingsManager* = MComponent()

proc refreshSettings(state: var SettingsManagerState) {.async.} =
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
  state.showingCateogry = cstring"main"
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
    finally:
        discard reload()

    state.allowRedraw = true
    await state.refreshSettings()

  let clear = eventHandler:
    e.redraw = false
    state.allowRedraw = true
    discard state.refreshSettings()
    
  let cb = proc(selection: cstring) =
    state.allowRedraw = true
    state.showingCateogry = selection
  if state.ready:
    mchildren(
      mdiv(m(TabSelect, a {callback: cb, selections: @[cstring"main", cstring"content", cstring"advanced"]})),
      mtable(
        a {class: "admin-settings"},
        mtr(mth"Setting", mth"Description",  mth"Default", mth"Value"),
        mchildren(
        block:
          var nodes = newSeq[VNode]()
          for setting in state.settings:
            if setting.category != state.showingCateogry: continue
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
                mtd(a {style: "min-width: 250px; font-size: 0.9em;"}, setting.description),
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


