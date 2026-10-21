#!/bin/bash
# Marker test for the php2shell fix: the patch disables session upload progress unconditionally.
# Unpatched PHP writes upload_progress_* into the session; patched does not.
# Usage (NOT on a server — installs packages; run in a throwaway container from the release folder):
#   docker run --rm --platform linux/amd64 -v "$PWD/debs:/o:ro" -v "$PWD/verify-fix.sh:/t.sh:ro" ubuntu:20.04 bash /t.sh ours
#   ('stock' instead of 'ours' runs the same test on unpatched Ubuntu php7.4 7.4.3 for comparison)
set -e; export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
if [ "$1" = ours ]; then cd /o; V=7.4.33-31+ubuntu20.04.1+deb.sury.org+1~local1
  apt-get install -y -qq --no-install-recommends $(for p in common json opcache readline cli fpm; do echo ./php7.4-${p}_${V}_amd64.deb; done) libfcgi-bin >/dev/null 2>&1
else apt-get install -y -qq --no-install-recommends php7.4-fpm libfcgi-bin >/dev/null 2>&1; fi
echo "php7.4-fpm $(dpkg-query -W -f='${Version}' php7.4-fpm)"
mkdir -p /run/php /srv /tmp/sess; chmod 1777 /tmp/sess
cat > /etc/php/7.4/fpm/conf.d/99-test.ini <<I
session.upload_progress.enabled=1
session.upload_progress.cleanup=0
session.save_path=/tmp/sess
I
echo '<?php echo "upload done\n";' > /srv/u.php
echo '<?php session_id("probe1234"); session_start(); echo "SESSION: ", json_encode(array_keys($_SESSION)), "\n";' > /srv/r.php
php-fpm7.4 -D; sleep 1
B=XyZ; { printf -- "--$B\r\nContent-Disposition: form-data; name=\"PHP_SESSION_UPLOAD_PROGRESS\"\r\n\r\nmark\r\n"; printf -- "--$B\r\nContent-Disposition: form-data; name=\"f\"; filename=\"x.bin\"\r\nContent-Type: application/octet-stream\r\n\r\n"; head -c 200000 /dev/zero; printf "\r\n--$B--\r\n"; } > /tmp/body
SCRIPT_FILENAME=/srv/u.php REQUEST_METHOD=POST CONTENT_TYPE="multipart/form-data; boundary=$B" CONTENT_LENGTH=$(stat -c%s /tmp/body) HTTP_COOKIE="PHPSESSID=probe1234" cgi-fcgi -bind -connect /run/php/php7.4-fpm.sock </tmp/body | tail -1
SCRIPT_FILENAME=/srv/r.php REQUEST_METHOD=GET cgi-fcgi -bind -connect /run/php/php7.4-fpm.sock </dev/null | tail -1
ls /tmp/sess
