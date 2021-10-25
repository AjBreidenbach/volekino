import mimetypes, os

let mimes = newMimetypes()
proc getMime*(f: string): string = mimes.getMimetype(splitFile(f).ext)
