{.emit: slurp("../vendor/mithril.js").}
import mithril
#import asyncjs
import mithril/common_selectors
import client/[jsffi, util, wsdispatcher, store, globals]
import client/[directory, convert, progress, login, user_menu, media, addmedia, log_view, sidenav]
import common/library_types

let mountPoint = document.querySelector(cstring"#mount")


view(Page404):
  mh1("page not found")


#else:
  #dlog(cstring "query = " & baseQueryString)
  
#[
var SideNav = MComponent()
SideNav.view = viewFn(MComponent):
  let query = getQuery()

  let tableView = query.hasOwnProperty(cstring"table")
  var useTableView = tableView
  let currentPath = getPath()
  if currentPath.len > 1:
    useTableView = not useTableView

  let libraryLink = cstring"/?" & mbuildQueryString(
    if useTableView:
      discard jsDelete query.table
      query
    else:
      query.table = cstring""
      query
  )

  mnav(
    m(mrouteLink,
      a {href: "/user-menu"},
      mimg(a {src: staticResource"/images/users.svg"})
    ),
    m(mrouteLink,
      a {href: libraryLink},
      (
        if useTableView:
          mimg(a {src: staticResource"/images/thumbnail-view.svg"})
        else:
          mimg(a {src: staticResource"/images/list-view.svg"})
      )
    ),
    #mimg(a {src: "/images/movie-camera.svg"}),
    m(mrouteLink,
      a {href: "/add"},
      mimg(a {src: staticResource"/images/add.svg"})
    ),
    m(mrouteLink,
      a {href: "/debug"},
      mimg(a {src: staticResource"/images/settings.svg"})
    )
  )
]# 

proc wrapPage(selector: MithrilSelector): MithrilSelector =
  #let sideNav = m(SideNav)
  view(wrapper):
    mchildren(
      mmain(
        a {class: if popupEnabled: "popup-enabled" else: ""},
        m(selector)
      ),
      SideNav,
      DownloadProgressPopupView
    )


  wrapper

var Debug = MComponent()
import sequtils
Debug.view = viewFn:
  mdiv(
    mh1("Debug info"),
    mchildren(
      logstatements.mapIt(mdiv(it))
    )
  )

block:

  mroute(
    mountPoint,
    "/404",
    {
      "/": wrapPage newDirectory(),
      "/convert/:uid": wrapPage Convert,
      "/library/:path": wrapPage Media,
      "/404": wrapPage Page404,
      "/progressbartest": toSelector TestProgressBar,
      "/login": wrapPage Login,
      "/register": wrapPage Registration,
      "/user-menu": wrapPage UserMenu,
      "/add": wrapPage AddMediaView,
      "/debug": wrapPage Debug,
      "/logs": wrapPage LogView

    }
  )

block:
  #let query = getQuery()
  #if isTruthy query.session:
    discard
    #document.cookie = cstring"session=" & query.session.to(cstring)



