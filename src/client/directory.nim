import mithril, mithril/common_selectors
import ./jsffi, ./entry, ./util
type Directory = ref object of MComponent

type Search = ref object of MComponent
  currentInput: cstring

proc newSearch: Search =
  var search = Search(currentInput: "")


  search.onbeforeupdate = beforeUpdateHook:
    var query = getQuery()
    result = not query.u.to(bool)# or not query.search.to(bool)
    echo result


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



proc newDirectory*: Directory =
  result = Directory()
  
  var library: seq[Entry]
  var requestComplete = false

  result.oninit = lifecycleHook:
    var response: JsObject
    handleErrorCodes:
      response = await mrequest("/api/library")
    echo "here"

    #if response.error.to(bool): console.log(response.error)
    library = response.to(seq[Entry])
    for entry in mitems library:
      init entry
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
        library
      )



