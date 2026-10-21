set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
cd /o; V=7.4.33-31+ubuntu20.04.1+deb.sury.org+1~local1
apt-get install -y -qq --no-install-recommends $(for p in common json opcache readline cli fpm mysql curl mbstring xml gd zip intl bcmath; do echo ./php7.4-${p}_${V}_amd64.deb; done) libfcgi-bin >/dev/null
php -v; php -m | tr '\n' ' '; echo
dpkg -l 'php7.4*' | awk '/^ii/{print $2, $3}' | head -3
mkdir -p /run/php /srv; php-fpm7.4 -t
cat > /srv/t.php <<'P'
<?php echo "ok ", PHP_VERSION, " upl=", ini_get('session.upload_progress.enabled'), " files=", json_encode(array_map(fn($f)=>[$f['name'],$f['size'],$f['error']], $_FILES)), " post=", json_encode($_POST), "\n";
P
php-fpm7.4 -D; sleep 1
B=XyZ; printf -- "--$B\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\n1\r\n--$B\r\nContent-Disposition: form-data; name=\"f\"; filename=\"x.txt\"\r\nContent-Type: text/plain\r\n\r\nhello\r\n--$B--\r\n" > /tmp/body
GET() { SCRIPT_FILENAME=/srv/t.php REQUEST_METHOD=$1 CONTENT_TYPE="$2" CONTENT_LENGTH=$3 cgi-fcgi -bind -connect /run/php/php7.4-fpm.sock; }
echo "--- GET"; GET GET "" 0 </dev/null | tail -1
echo "--- multipart"; GET POST "multipart/form-data; boundary=$B" $(stat -c%s /tmp/body) </tmp/body | tail -1
echo "--- urlencoded"; printf 'x=1&y=2' | GET POST application/x-www-form-urlencoded 7 | tail -1
grep -iE 'segfault|signal|SIGSEGV' /var/log/php7.4-fpm.log || echo "fpm log clean"
