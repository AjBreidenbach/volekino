{.emit: slurp("../vendor/mithril.js").}
import mithril
#import asyncjs
import mithril/common_selectors
import client/[jsffi, directory, convert, progress, wsdispatcher, login, admin, media, util]
import common/library_types


let mountPoint = document.querySelector(cstring"#mount")


view(Page404):
  mh1("page not found")



var SideNav = MComponent()
SideNav.view = viewFn(MComponent):
  let query = getQuery()

  let tableView = query.hasOwnProperty(cstring"table")
  var useTableView = tableView
  let currentPath = getPath()
  if currentPath.len > 1:
    useTableView = not useTableView

  let libraryLink = cstring"/?" & mbuildQueryString(if useTableView:
    discard jsDelete query.table
    query
  else:
    query.table = cstring""
    query
  )

  mnav(
    mimg(a {src: "/images/users.svg"}),
    m(mrouteLink,
      a {href: libraryLink},
      (
        if useTableView:
          mimg(a {src: "/images/thumbnail-view.svg"})
        else:
          mimg(a {src: "/images/list-view.svg"})
      )
    ),
    mimg(a {src: "/images/movie-camera.svg"}),
    mimg(a {src: "/images/add.svg"}),
    mimg(a {src: "/images/settings.svg"})
  )
  

proc wrapPage(selector: MithrilSelector): MithrilSelector =
  #let sideNav = m(SideNav)
  view(wrapper):
    mchildren(
      mmain(
        m(selector)
      ),
      SideNav
    )
    


  wrapper

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
      "/admin": wrapPage Admin

    }
  )
#


