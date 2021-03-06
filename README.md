![VOLEKINO](https://volekino.com/images/logo-gh.svg)


VoleKino is a media server package integrating httpd, ffmpeg, the openssh client, transmission and others, with the goal of making self-hosting a media server as easy as possible.

VoleKino is written almost entirely in the [Nim](https://nim-lang.org) programming language.

When run through a proxy server, a VoleKino user does not need to forward ports or have a public IP address to stream videos with peers.

* [Installation](#installation)
* [Usage and Options](#usage-and-options)
* [Configuration](#configuration)
* [Building](#building)
  * [Building with Docker](#building-with-docker)
* [License](#license)
* [Software Credits](#software-credits)
* [Potential Improvements](#potential-improvements)

# Installation
Currently the only provided method for installing VoleKino is via a Debian package.  Help implementing support for snap packages, appimages, and Termux's build script would be greatly appreciated.

VoleKino supports Debian based Linux distributions, and Android, with the Termux app.

Windows support is a wish list item, although VoleKino can be run on Windows with either the Linux or Android subsystems.

For installation guides, visit [https://volekino.com/downloads](https://volekino.com/downloads).

# Usage and Options
VoleKino can be launched in GUI mode with `volekino --gui`.  This is the default invocation when using the desktop launcher.  Launching in GUI mode creates an admin session to help get things set up.

Running the `volekino` command for the first time will start a server listening on port 7000.  Subsequent executions of the `volekino` command trigger a sync of the files contained in the media directory (default location: `$HOME/.local/share/VoleKino/media`).

VoleKino can be exited from the command line with CTRL+C or `pkill -2 volekino`.  VoleKino can also be restarted from within the GUI.

# Configuration
Settings can be changed from within the admin panel. ![VoleKino settings window](https://volekino.com/images/index/admin.webp)
A full list of settings can also be found in `default-settings.yml`.
Settings can be changed in VoleKino on the command line with the `--settings` flag.  Settings are passed through stdin.
```
cat <<EOF volekino --settings
proxy-server=volekino.com
proxy-server-token=andrew:123
EOF
```
Not all settings are currently supported.


# Contributing
Contributions to VoleKino are welcome, whether they are in the form of feature requests, suggestions, or application code.  I'm currently trying to figure out the best way to set up integration tests.  That should make future collaboration much more straightforward.

# Building
Building VoleKino from source requires the following packages be installed on your system.
* git
* nodejs
* nim
* gcc/clang

Building VoleKino with webview enabled requires the following additional packages:
* pkg-config 
* libgtk-3-dev 
* libwebkit2gtk-4.0-dev

To avoid building with webview, pass `-d:ui_launcher='false'` when invoking the nimble build script.  Alternatively, you may specify another command to launch the VoleKino ui with such as `-d:ui_launcher='xdg-open'`

Before building, run `npm i` to install nodejs build dependencies.  If you will be distributing the build, please run `node ./scripts/generate-software-credits.js`.  It will download the licenses of all the nimble and npm dependencies, so they can be distributed with your build.  They will be included automatically when running the nimble build script.

To build VoleKino run `nimble buildAll -d:release`.  The resulting program will be located in the `dist/` folder.

Running VoleKino generally requires the following packages:
* ffmpeg
* apache2/httpd
* transmission
* openssh-client
* util-linux

Some dependencies may be omitted if you do not plan on using them. For example, you do not need transmission if you don't plan on downloading torrents.

If VoleKino was built with webview, the following will be required as additional runtime dependencies:
* libgtk-3
* libwebkit2gtk-4.0

## Building with Docker
This repository contains a dockerfile for building and running VoleKino.  It can be built with `docker build . -f docker/volekino.Dockerfile --build-arg VOLEKINO_BUILD=prod -t volekino:latest`.

Two environment variables are provided to let you connect to the running instance directly through volekino.com (or another proxy/gateway server).  They can be used as `docker run -e PROXY_SERVER="volekino.com" -e PROXY_SERVER_TOKEN="andrew:123" volekino:latest`.

All persistent VoleKino data in the provided image is kept in `/home/volekino/.local/share/VoleKino`.  If you are creating a bind mount with a source directory from the host file system, you will need to run `sudo chown 1000:1000 <source-directory>` to provide access, as the docker image entry-point is not run as root.  This step is not necessary for named volumes.



# License
VoleKino is distributed under the Apache-2.0 license.
# Software Credits
**[Prologue](https://github.com/planety/prologue) by [Planety](https://github.com/planety)** <br>
*Licensed under [Apache-2.0](https://raw.githubusercontent.com/planety/prologue/devel/LICENSE)* 

**[appdirs](https://github.com/MatthewScholefield/appdirs) by [Jonathan Frere](https://github.com/MrJohz) with contributions by [Matthew Scholefield](https://github.com/MatthewScholefield)** <br>
*Licensed under [MIT](https://github.com/MatthewScholefield/appdirs/raw/master/LICENSE.txt)*

**[zippy](https://github.com/guzba/zippy) by [Ryan Oldenburg](https://github.com/guzba)** <br>
*Licensed under [MIT](https://github.com/guzba/zippy/raw/master/LICENSE)*

**[mithril.js](https://mithril.js.org/) by MithrilJs** <br>
*Licensed under [MIT](https://raw.githubusercontent.com/MithrilJS/mithril.js/next/LICENSE)*

**[jswebsockets](https://github.com/stisa/jswebsockets) by [Silvio](https://github.com/stisa)** <br>
*Licensed under [MIT](https://raw.githubusercontent.com/stisa/jswebsockets/master/LICENSE)*

**[webview](https://github.com/webview/webview) by [webview](https://webview.dev/)** <br>
*Licensed under [MIT](https://github.com/webview/webview/raw/master/LICENSE)* <br>
Nim wrapper provided by [oskca](https://github.com/oskca)

**[psutil-nim](https://github.com/johnscillieri/psutil-nim) by [Juan Carlos](https://github.com/juancarlospaco)** <br>
*Licensed under [MIT](https://github.com/johnscillieri/psutil-nim/raw/master/LICENSE)*

**[nimcrypto](https://github.com/cheatfate/nimcrypto) by [Eugene Kabanov](https://github.com/cheatfate)** <br>
*Licensed under [MIT](https://github.com/cheatfate/nimcrypto/raw/master/LICENSE)*

**[websocketx](https://github.com/xflywind/websocketx) by [xflywind](https://github.com/xflywind)** <br>
*Licensed under [MIT](https://github.com/xflywind/websocketx/raw/master/LICENSE)* 

**[cligen](https://github.com/c-blake/cligen) by [c-blake](https://github.com/c-blake)** <br>
*Licensed under [ISC](https://github.com/c-blake/cligen/raw/master/LICENSE)* 

**[pug](https://pugjs.org/) by [TJ Holowaychuk](https://github.com/tj)** <br>
*Licensed under [MIT](https://github.com/pugjs/pug/raw/master/packages/pug/LICENSE)* 

**[sass](https://github.com/sass/dart-sass) by Google Inc.** <br>
*Licensed under [MIT](https://github.com/sass/dart-sass/raw/main/LICENSE)* 

**[terser](https://github.com/terser/terser) by [Mihai Bazon](https://lisperator.net/)** <br>
*Licensed under [BSD](https://github.com/terser/terser/raw/master/LICENSE)* 

**[yaml-cli](https://github.com/terser/terser) by [Daniel Yoder](https://www.pandastrike.com/)** <br>
*Licensed under [ISC](https://github.com/pandastrike/yaml-cli/raw/master/LICENSE)* 

**[markedjs](https://github.com/markedjs/marked) by [Christopher Jeffrey](https://github.com/chjj/)**
*Licensed under [multiple licenses](https://github.com/markedjs/marked/raw/master/LICENSE.md)* 

**[node-html-parser](https://github.com/taoqf/node-html-parser) by [Tao Qiufeng](https://github.com/taoqf)**
*Licensed under [MIT](https://github.com/taoqf/node-html-parser/raw/main/LICENSE)* 

# 
All licenses are distributed with VoleKino and can be viewed in the info tab.


# Potential Improvements
* Sleep when using mobile data (Android/Termux)
* Allow client to be used as a progressive web app
* Show which videos are currently being watched and by whom
* Use websockets for tunneling HTTP instead of SSH to avoid TCP over TCP
* Publish standalone Android app
* Allow down-scaling for conversions that involve transcoding video
* Provide configuration of Apache through VoleKino (particularly interested in toggling sendfile and memcopy)
* Stream encoding h264 for compatibility
* Directory access permission controls
