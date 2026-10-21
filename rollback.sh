#!/bin/bash
# Откат на сохранённые install.sh пакеты -16. Запуск: bash rollback.sh /root/php74-backup-YYYYMMDD-HHMM
set -euo pipefail
BK=${1:?укажи папку бэкапа}
apt-get install -y --allow-downgrades --no-install-recommends \
  -o Dpkg::Options::=--force-confold "$BK"/debs/*.deb
php-fpm7.4 -t
systemctl restart php7.4-fpm
systemctl is-active php7.4-fpm
dpkg -l 'php7.4*' | awk '/^ii/{print $2, $3}'
