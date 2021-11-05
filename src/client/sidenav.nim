import mithril, mithril/common_selectors
import ./jsffi,  ./util, ./globals

var SideNav* = MComponent()
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

  let restartHandler = eventHandler:
    discard reload()


  var sidenavItems: seq[VNode]

  if not isLoggedIn() and getPath() != cstring"/login":
    sidenavItems.add m(mrouteLink,
      a {href: "/login"},
      mimg(a {src: staticResource"/images/login.svg"})

    )

  if isAdmin():
    sidenavItems.add m(mrouteLink,
        a {href: "/user-menu"},
        mimg(a {src: staticResource"/images/users.svg"})
      )

  sidenavItems.add m(mrouteLink,
      a {href: libraryLink},
      (
        if useTableView:
          mimg(a {src: staticResource"/images/thumbnail-view.svg"})
        else:
          mimg(a {src: staticResource"/images/list-view.svg"})
      )
    )
  if isAdmin():
    sidenavItems.add m(mrouteLink,
        a {href: "/add"},
        mimg(a {src: staticResource"/images/add.svg"})
      )


  sidenavItems.add m(mrouteLink,
      a {href: "/info"},
      mimg(a {src: staticResource"/images/info.svg"})
    )

  if isAdmin():
    sidenavItems.add mdiv(
          a {onclick: reload, class: "restart-container"},
          mimg(a {style: "", src: staticResource"/images/exchange.svg"}),
          mspan(a {style: "color: white; font-size: 0.9em; text-align: center; font-weight: 700; display: inline-block; text-shadow: 1px 1px 1px grey;"}, "Restart")
        )

  if isLoggedIn():
    let onclick = eventHandler:
      discard logout()
    sidenavItems.add mdiv(
      a {class: "logout-container", onclick: onclick},
      mimg(a {src: staticResource"/images/logout.svg"})

    )



  mnav(sidenavItems)
 
