from ubuntu as build
run apt-get update --fix-missing
run DEBIAN_FRONTEND="noninteractive" apt-get install curl tar xz-utils git build-essential -y

workdir root
run curl https://nim-lang.org/download/nim-1.4.8-linux_x64.tar.xz > nim.tar.xz
run curl https://nodejs.org/dist/v14.17.6/node-v14.17.6-linux-x64.tar.xz > node.tar.xz
run tar -xvf nim.tar.xz
run tar -xvf node.tar.xz
env PATH="/root/nim-1.4.8/bin:/root/node-v14.17.6-linux-x64/bin:${PATH}"
copy package-lock.json package.json ./
run npm i
copy volekino.nimble ./
run nimble install -dy
copy userdata.nim ./
copy default-settings.yml ./
copy client client/
copy scripts scripts/
copy src src/
copy userdata userdata/
copy vendor vendor/
arg VOLEKINO_BUILD="development"
run nimble buildAll -d:ui_launcher='false'

from ubuntu as dev
run useradd volekino
run apt-get update --fix-missing && DEBIAN_FRONTEND="noninteractive" apt-get install apache2 ffmpeg transmission-daemon openssh-client -y
workdir /home/volekino
run mkdir -p /home/volekino/.local/share/VoleKino
run chown volekino:volekino /home/volekino/ /home/volekino/.local/share/VoleKino
copy --from=build /root/dist/ ./dist
env PROXY_SERVER=""
env PROXY_SERVER_TOKEN=""
env USER=volekino
user volekino:volekino
expose 7000/tcp
#run ./dist/volekino -e --api=false --sync=false --apache=false
#copy test-resources/ /home/volekino/.local/share/VoleKino/media
cmd ./dist/volekino -e --settings < /dev/null
