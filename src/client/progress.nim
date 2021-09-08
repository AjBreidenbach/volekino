import mithril, mithril/common_selectors
import jsffi


import strformat


var ProgressBar* = MComponent()

ProgressBar.view = viewFn(JsObject):
  let value = if vnode.attrs.hasOwnProperty(cstring"value"):
      vnode.attrs.value.to(int)
    else:
      0

  var containerStyle = cstring""
  if vnode.attrs.hasOwnProperty(cstring"width"):
    containerStyle &= &"width: {vnode.attrs.width.to(cstring)}"
    


  mdiv(
    a {class: "progress-bar-container", style: containerStyle},
    mdiv(
      a {class: "progress-bar-inner"},
      mdiv(
        a {class: "progress-bar-value", style: &"width: {value}%"}
      )
    )
  )
  


var TestProgressBar* = MComponent()

TestProgressBar.view = viewFn(JsObject):
  mchildren(
    m(ProgressBar, a {width: "300px", value: 50}),
    m(ProgressBar)
  )
  


