#!/bin/bash
# Read-only check on the server: is the patched php7.4 installed AND actually running?
# Usage: sudo bash check-installed.sh
V='1:7.4.33-31+ubuntu20.04.1+deb.sury.org+1~local1'
FPM_SHA='9c0f06f2e73ab11b43e74c0720261aaff202003dd20615e793593a42495f1067'
ok=1

cur=$(dpkg-query -W -f='${Version}' php7.4-fpm 2>/dev/null)
if [ "$cur" = "$V" ]; then echo "OK   php7.4-fpm package $cur"; else echo "FAIL php7.4-fpm package: ${cur:-not installed}"; ok=0; fi

sha=$(sha256sum /usr/sbin/php-fpm7.4 2>/dev/null | cut -d' ' -f1)
if [ "$sha" = "$FPM_SHA" ]; then echo "OK   /usr/sbin/php-fpm7.4 sha256 matches this build"; else echo "FAIL /usr/sbin/php-fpm7.4 sha256 $sha"; ok=0; fi

pid=$(systemctl show -p MainPID --value php7.4-fpm 2>/dev/null)
if [ -n "$pid" ] && [ "$pid" != 0 ]; then
  stale=0
  for p in $pid $(pgrep -P "$pid"); do
    readlink "/proc/$p/exe" | grep -q deleted && stale=$((stale+1))
  done
  if [ $stale = 0 ]; then echo "OK   running php-fpm processes use the new binary"; else echo "FAIL $stale php-fpm processes still run the old binary — systemctl restart php7.4-fpm"; ok=0; fi
else
  echo "--   php7.4-fpm is not running"
fi

if dpkg -l libapache2-mod-php7.4 2>/dev/null | grep -q '^ii'; then
  apid=$(systemctl show -p MainPID --value apache2 2>/dev/null)
  if [ -n "$apid" ] && [ "$apid" != 0 ] && grep -q 'libphp7.4.so (deleted)' "/proc/$apid/maps" 2>/dev/null; then
    echo "FAIL apache2 still has the old mod_php loaded — systemctl restart apache2"; ok=0
  else
    echo "OK   apache2 mod_php"
  fi
fi

ini=$(php-fpm7.4 -i 2>/dev/null | awk -F'=> ' '/^session.upload_progress.enabled/{print $2; exit}')
echo "info session.upload_progress.enabled (fpm) = ${ini:-?}  (Off recommended)"

[ $ok = 1 ] && echo "RESULT: patched build is installed and running" || { echo "RESULT: NOT OK"; exit 1; }
