import mithril, mithril/common_selectors
import sequtils
import ./jsffi

var TabSelect* = MComponent()

type TabSelectState = ref object
  currentSelection: cstring
  title: cstring
  selections: seq[cstring]
  callback: proc(selection: cstring): void


TabSelect.oninit = lifecycleHook(TabSelectState):
  state.selections = vnode.attrs.selections.to(seq[cstring])
  state.callback = vnode.attrs.callback.to(type state.callback)
  state.title = vnode.attrs.title.to(cstring)
  if isFalsey state.selections:
    state.selections = @[]
  else: state.currentSelection = state.selections[0]
  if jsTypeOf(toJs state.callback) != cstring"function":
    state.callback = console.log.to(type state.callback)
  if isFalsey state.title:
    state.title = cstring"Select"
  
  #state = TabSelectState(selections: selections, currentSelection: selections[0], callback: callback, title: title)
  
TabSelect.view = viewFn(TabSelectState):
  mdiv(
    a {class:"tab-select"},
    mdiv(a {class:"title"}, state.title),
    mchildren(
      state.selections.mapIt(
        block:
          var 
            click: EventHandler
            class = cstring"selection"
          closureScope:
            let it = it
            click = eventHandler:
              state.currentSelection = it
              state.callback(it)

            if state.currentSelection == it:
              class = class & cstring" active"

          mdiv(a {class: class, onclick: click}, it)
      )
    )

  )
  
