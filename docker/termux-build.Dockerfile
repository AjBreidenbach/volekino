#docker pull xeffyr/termux:aarch64
from xeffyr/termux:aarch64
run pkg i nodejs curl build-essential binutils git -y
run printf 'nim-lang.org\ndlcdn.apache.org\n' >> /system/etc/static-dns-hosts.txt
run /system/bin/update-static-dns
run curl https://nim-lang.org/download/nim-1.4.8.tar.xz > /tmp/nim.tar.xz
run curl https://dlcdn.apache.org//httpd/httpd-2.4.51.tar.gz > /tmp/httpd.tar.gz
run tar -xvf /tmp/nim.tar.xz
workdir /data/data/com.termux/files/home/nim-1.4.8
run sh build.sh && bin/nim c koch && ./koch boot -d:release && ./koch tools
workdir /data/data/com.termux/files/home
run tar -xvf /tmp/httpd.tar.gz
workdir /data/data/com.termux/files/home/httpd-2.4.51/srclib
run curl https://dlcdn.apache.org//apr/apr-1.7.0.tar.gz > apr.tar.gz
run curl https://dlcdn.apache.org//apr/apr-util-1.6.1.tar.gz > apr-util.tar.gz
run tar -xvf apr.tar.gz 
run tar -xvf apr-util.tar.gz 
run mv apr-1.7.0/ apr 
run mv apr-util-1.6.1/ apr-util
run rm *.tar.gz
workdir /data/data/com.termux/files/home/httpd-2.4.51
env CFLAGS="-O2"

run ./configure --prefix=$PREFIX/../opt/volekino \
--with-included-apr \
--with-mpm=event \
--enable-mods-shared=none \
--enable-mods-static='dir headers authz_core access_compat mime proxy proxy_http proxy_wstunnel watchdog log_config logio version unixd slotmem_shm'

run make
run make install

env PATH=$PATH:/data/data/com.termux/files/home/nim-1.4.8/bin
workdir /data/data/com.termux/files/home/volekino
copy volekino.nimble .
run nimble install -y -d --noSSLCheck
#
#  LoadModule mpm_event_module ${APACHE_MODULES_DIR}mod_mpm_event.so
#  LoadModule dir_module ${APACHE_MODULES_DIR}mod_dir.so
#  LoadModule headers_module ${APACHE_MODULES_DIR}mod_headers.so
#  LoadModule authz_core_module ${APACHE_MODULES_DIR}mod_authz_core.so
#  LoadModule access_compat_module ${APACHE_MODULES_DIR}mod_access_compat.so
#  LoadModule mime_module ${APACHE_MODULES_DIR}mod_mime.so
#  LoadModule proxy_module ${APACHE_MODULES_DIR}mod_proxy.so
#  LoadModule proxy_http_module ${APACHE_MODULES_DIR}mod_proxy_http.so
#  LoadModule proxy_wstunnel_module ${APACHE_MODULES_DIR}mod_proxy_wstunnel.so
