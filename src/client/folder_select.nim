import mithril, mithril/common_selectors

var FolderSelectForm* = MComponent()

FolderSelectForm.view = viewFn:
  mdiv(
    mh5(a {style:"margin: 1em 0 0 0; text-align: center"}, "Add a folder from your device to your VoleKino library"),
    mform(
      mlabel(
        minput(a {placeholder: "Location :", style:"width: 100%", type:"text", disabled:true})
      ),
      mcenter(
        minput(a {style:"width:200px; max-width:unset;", type:"submit", value:"Select"})
      )
    )

  )
  
