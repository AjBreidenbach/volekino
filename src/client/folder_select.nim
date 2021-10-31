import mithril, mithril/common_selectors
import ../common/library_types
import ./globals, ./jsffi
import asyncjs, sequtils
import wsdispatcher


proc encodePath(p: cstring): cstring =
  p.replace(newRegExp(cstring"/", cstring"g"), cstring"$")

proc joinWithSlash(s1, s2a: cstring): cstring =
  var s2 = s2a
  if s2a.startsWith(cstring"$"):
    s2 = s2a.slice(1)

  if s1.endsWith(cstring"/") and s2.startsWith(cstring"/"):
    s1.slice(0, -1) & s2
  elif s1.endsWith(cstring"/") or s2.startsWith(cstring"/"):
    s1 & s2
  else:
    s1 & cstring"/" & s2
proc isOpen(vnode: JsObject): bool =
  vnode.attrs.open.to(bool)

proc runcb(vnode: JsObject, argument: cstring) =
  if jsTypeOf(vnode.attrs.callback) == cstring"function":
    vnode.attrs.callback(argument)

const
  SORT_NAME_ASC = 0
  SORT_DATE_ASC = 1
  SORT_NAME_DESC = 2
  SORT_DATE_DESC = 3


type SelectionWindowState = ref object
  currentDirectory: cstring
  directoryContents: seq[FileEntry]
  fileSelection: cstring
  sortCriteria: int


proc sort(state: var SelectionWindowState) =
  state.directoryContents.sort do (fe1, fe2: FileEntry) -> int:
    case state.sortCriteria:
    of SORT_NAME_ASC:
      fe1.filename.localeCompare(fe2.filename)
    of SORT_NAME_DESC:
      fe2.filename.localeCompare(fe1.filename)
    of SORT_DATE_ASC:
      int(fe1.lastModified - fe2.lastModified)
    else:
      int(fe2.lastModified - fe1.lastModified)

proc setCurrentDirectory(state: var SelectionWindowState, dir: cstring, background=false) {.async.} =
  state.currentDirectory = dir
  state.fileSelection = cstring""
  state.directoryContents = (await mrequest(apiPrefix(joinWithSlash(cstring"files", encodePath(dir))), background=background)).to(seq[FileEntry])
  state.sort()

var SelectionWindow = MComponent()

proc displayDate*(t: float | int): VNode =
  let d = newDate(t * 1000)
  mchildren(
    mtd(a {style: "text-align: right; font-family: monospace; width: 80px;"}, d.toLocaleDateString().to(cstring)),
    mtd(a {style: "text-align: right; font-family: monospace; width: 50px;"}, d.toLocaleTimeString(cstring"en-GB").to(cstring).slice(0,-3))
  )


SelectionWindow.oninit = lifecycleHook(SelectionWindowState):
  #state.currentDirectory = cstring""
  state.directoryContents = @[]
  state.sortCriteria = SORT_NAME_ASC
  #state.directoryContents = 
  discard state.setCurrentDirectory("")


SelectionWindow.view = viewFn(SelectionWindowState):
  if not vnode.isOpen:
    return nil

  let goup = eventHandler:
    let targetDirectory = state.currentDirectory.split(cstring"/").slice(0, -1).join(cstring"/")
    discard state.setCurrentDirectory(targetDirectory)

  let handleDirectInput = eventHandler:
    e.redraw = false
    discard state.setCurrentDirectory(e.target.value.to(cstring))

  mdiv(
    a {class: "window-select-container", style: ""},
    mdiv(
      a {style: "text-align: center; margin-top: 2em;"},
      "Add a file or folder from your device to your VoleKino library"),
    mdiv(
      a {style: "box-shadow: 0px 0px 10px #b3b3b3;"},
      mdiv(
        mdiv(
          a {style: "; background-color: #8ed9ea; min-height: 3em; display: flex; align-items: center; justify-content: space-evenly; flex-wrap: wrap;;"},
          mdiv(
            a {style: "display: flex; align-items: center;"},
            mlabel(
              a {style: "margin: 0.5em"},
              "Location:",
              minput(a {onchange: handleDirectInput, style: "margin: 0.5em; font-size: 0.9em;", type: "text", value: state.currentDirectory})
            ),
            block:
              var style = cstring"margin-right: 1em;"
              if state.currentDirectory.len == 0:
                style = style & cstring"opacity: 0.5"
              mimg(a {style: style, src: staticResource"/images/up-arrow.svg", onclick: goup})
          ),
          mdiv(
            mspan("Sort"),
            mselect(
              a {
                style: "font-family: inherit; font-size: 0.9em; background-color: #f0f0f0; outline-style: none; border-style: none; padding: 0.5em ; margin: 0.5em;",
                onchange: (
                  proc(e: JsObject) =
                    state.sortCriteria = e.target.selectedIndex.to(int)
                    state.sort()
                  
                    
                )
              },
              moption("Name Asc."),
              moption("Date Asc."),
              moption("Name Desc."),
              moption("Date Desc.")
            )
          )
        )
      ),
      mdiv(
        a {class: "file-entry-container", style: ""},
        if state.directoryContents.len == 0:
          mspan "No media files found"
        else:
          mchildren(
            mtable(
              a {style: "width: 100%; border-collapse: collapse;"},
              mtr(
                mth(a {style: "width: 1.5em;"}),
                mth("File"),
                mth(a {colspan: 2, style: "width: 130px;"}, "Last modified")
              ),
              mtbody(
                a {class: "noselect pointer"},
                state.directoryContents.mapIt(
                  block:
                    var clickHandler: EventHandler
                    closureScope:
                      let fileEntry = it
                      clickHandler = eventHandler:
                        if fileEntry.kind == DirFileEntry:
                          discard state.setCurrentDirectory(joinWithSlash(state.currentDirectory, fileEntry.filename))
                        else:
                          if state.fileSelection != fileEntry.filename:
                            state.fileSelection = fileEntry.filename
                          else: state.fileSelection = cstring""
                      
                    var style = cstring"background-color: white;"
                    if state.fileSelection == it.filename:
                      style = style & cstring"filter: invert(1);"
                    mtr(
                      a {style: style, onclick: clickHandler},
                      mtd(
                        a {style: "width: 1.5em;"},
                        mimg(
                          a {src: (
                            if it.kind == MediaFileEntry: staticResource"/images/media.svg"
                            else: staticResource"/images/open-folder.svg"
                          ), style: (
                            if state.fileSelection == it.filename: cstring"width: 1em; filter: saturate(10);"
                            else: cstring"width: 1em;"
                          )}
                        )
                      ),
                      mtd(it.filename),
                      #mtd(a {style: "max-width: 180px; display: flex; justify-content: space-between;"}, displayDate(it.lastModified))
                      displayDate(it.lastModified)
                    )
                )
              )
            ),
            mdiv(
              a {style: "position: sticky; bottom: -1em; padding: 0.5em; margin-top: 1em; background: white; display:flex; justify-content: end;"},
              block:
                let onclick = eventHandler:
                  runcb(vnode, cstring"")
                  discard state.setCurrentDirectory("", background=true)
                mbutton(
                  a {onclick: onclick, style: "width: 100px; margin: 0 0.5em; height: 2em; background: #f0f0f0"},
                  "Cancel"
                )
              ,
              block:
                let onclick = eventHandler:
                  if state.fileSelection.len + state.currentDirectory.len == 0:
                    e.redraw = false
                    return
                
                  runcb(vnode, joinWithSlash(state.currentDirectory, state.fileSelection))
                  discard state.setCurrentDirectory("", background=true)

                var style = cstring"width: 100px; margin: 0 0.5em; height: 2em;"
                if state.fileSelection.len + state.currentDirectory.len == 0:
                  style = style & cstring"background: #f0f0f0"
                mbutton(
                  a {onclick: onclick, style: style},
                  if state.fileSelection.len > 0: "Select File"
                  else: "Select"
                )
            )
          )
      )
    )
  )
    


type FolderSelectFormState = ref object
  selectWindowStatus: bool
  currentSelection: cstring
  feedback: cstring

var FolderSelectForm* = MComponent()

FolderSelectForm.oninit = lifecycleHook(FolderSelectFormState):
  state.selectWindowStatus = false
  #state.currentSelection = cstring""
  
FolderSelectForm.view = viewFn(FolderSelectFormState):
  
  proc selectionWindowCb(s: cstring) =
    state.selectWindowStatus = false
    state.currentSelection = s
    

  let openWindow = eventHandler:
    state.selectWindowStatus = true

  let confirm = eventHandler:
    discard mrequest(apiPrefix(joinWithSlash("files", encodePath(state.currentSelection))), Post, background=true)
    state.currentSelection = cstring""
    state.feedback = cstring"Selection added"

    dispatchEvent(cstring"updatemedialist", jsNull)
    
    discard timeout(5000):
      state.feedback = cstring""
      if getPath() == cstring"/add":
        mredraw()

  mdiv(
    a {style: "position: relative"},
    m(SelectionWindow, a {callback: selectionWindowCb, open: state.selectWindowStatus}),
    block:
      if isTruthy state.feedback:
        mcenter(a {style: "width: 100%; position: absolute; top: 100%; "}, state.feedback)
      else: nil
    ,
    mh5(a {style:"margin: 1em 0 0 0; text-align: center"}, "Add a folder from your device to your VoleKino library"),
    mform(
      #a {onclick: onclick}
      mdiv(
        a {onclick: openWindow, style: "margin: 0.5em;"},
        minput(a {value: state.currentSelection, placeholder: "Location :", style:"width: 100%", type:"text", disabled:true})
      ),
      mcenter(
        if isTruthy state.currentSelection:
          minput(a {onclick: confirm, style:"width:200px; max-width:unset;", type:"submit", value: "Confirm"})
        else:
          minput(a {onclick: openWindow, style:"width:200px; max-width:unset;", type:"submit", value: "Select"})
        #minput(a {style:"width:200px; max-width:unset;", type:"submit", value: (if isTruthy state.currentSelection: "Confirm" else: "Select")})
      )
    )
  )
  
