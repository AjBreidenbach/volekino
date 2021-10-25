import mithril, mithril/common_selectors
import ./jsffi, ./entry, ./util, ./globals
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
        mimg(a {src: staticResource"/images/search.svg"}),
        minput(a {type: "search", oninput: oninput, value: search.currentInput})
      )
    )

    
  search


var subdirectories = newJsSet()


var BreadCrumbs = MComponent()

BreadCrumbs.view = viewFn:
  var query = getQuery()
  let search = query.search.to(cstring)
  #console.log(search)
  if (isFalsey search):
    return mchildren()
  elif not (cstring"/" in search):
    discard jsDelete query.search
    return mdiv(
      m(mrouteLink,
        a {href: cstring"/?" & mbuildQueryString(query)},
        mimg(a {style: "margin-bottom: -5px;", src: staticResource"/images/home.svg"})
      )
    )
    
  discard jsDelete query.search
  
  mdiv(
    m(mrouteLink,
      a {href: cstring"/?" & mbuildQueryString(query)},
      mimg(a {style: "margin-bottom: -5px;", src: staticResource"/images/home.svg"})
    ),

    block:
      var children = newSeq[VNode]()
      var path = cstring"/?search="
      var pathComponents = search.split(cstring"/")
      if pathComponents[^1].len == 0:
        discard pathComponents.pop()
      for (i, pathComponent) in pathComponents.pairs():
        #echo "pair ", i
        path &= (pathComponent & cstring"%2F")
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
      response = await mrequest(apiPrefix"/library")

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



