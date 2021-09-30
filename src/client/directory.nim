import mithril, mithril/common_selectors
import ./jsffi, ./entry, ./util
#import algorithm
type Directory = ref object of MComponent

type Search = ref object of MComponent
  currentInput: cstring

proc newSearch: Search =
  var search = Search(currentInput: "")


  search.onbeforeupdate = beforeUpdateHook:
    var query = getQuery()
    result = not query.u.to(bool)# or not query.search.to(bool)
    #echo result


  let oninput = eventHandler:
    var query = getQuery()
    query.search = e.target.value
    discard jsDelete query.u
    e.redraw = false
    mrouteset(getPath() & cstring"?" & mbuildQueryString(query))

  search.view = viewFn(Search):
          

      
    var query = getQuery()

    if query.hasOwnProperty("search"):#search.to(bool):
      search.currentInput = query.search.to(cstring)
    

    mdiv(
      a {class: "directory-top"},
      mdiv(
        a {class: "search-container"},
        mimg(a {src: "/images/search.svg"}),
        minput(a {type: "search", oninput: oninput, value: search.currentInput})
      )
    )

    
  search


var subdirectories = newJsSet()


var BreadCrumbs = MComponent()

BreadCrumbs.view = viewFn:
  var query = getQuery()
  let search = query.search.to(cstring)
  if not (search in subdirectories):
    return mchildren()
  discard jsDelete query.search
  
  mdiv(
    m(mrouteLink,
      a {href: cstring"/?" & mbuildQueryString(query)},
      "/home"
    ),

    block:
      var children = newSeq[VNode]()
      var path = cstring""
      let pathComponents = search.split(cstring"/")
      for (i, pathComponent) in pathComponents.pairs():
        #echo "pair ", i
        path &= pathComponent
        if i != pathComponents.high:
          children.add m(mrouteLink, a {href: path}, cstring"/" & pathComponent)
        else: children.add(mspan(cstring"/" & pathComponent))
      mchildren(children)


    #search
  )

proc newDirectory*: Directory =
  result = Directory()
  
  var library: seq[Entry]
  var requestComplete = false

  result.oninit = lifecycleHook:
    var response: JsObject
    handleErrorCodes:
      response = await mrequest("/api/library")

    #if response.error.to(bool): console.log(response.error)
    library = response.to(seq[Entry])
    
    for entry in mitems library:
      #[
      var sliceEnd = entry.path.rfind('/')
      if sliceEnd != -1:
        let containingDirectory = entry.path.slice(0, sliceEnd)
        subdirectories.incl containingDirectory
      ]#
      init entry

      if entry.containingDirectory.len > 0:
        subdirectories.incl entry.containingDirectory
        
    library.sort do (e1, e2: Entry) -> int:
      #using res or return here breaks js async macro
      var res = localeCompare(e1.containingDirectory, e2.containingDirectory)
      if res == 0:
        res = localeCompare(e1.pathTail, e2.pathTail)
      res


    requestComplete = true
  

  let search = newSearch()
  result.view = viewFn(Directory):
    if not requestComplete:
      mh1("Loading library...")
    elif library.len == 0:
      mh1("Library is empty")
    else:
      mdiv(
        a {class: "library-container"},
        search,
        m(BreadCrumbs),
        library
      )



