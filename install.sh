#!/bin/bash
# Обновление php7.4 (Surý, Ubuntu 20.04 amd64) до 1:7.4.33-31 — фикс CVE-2026-109618/109619.
# Ставит только те php7.4-* пакеты, что уже установлены. Запуск от root:
#   cd php74-31-focal-amd64 && bash install.sh
set -euo pipefail
cd "$(dirname "$0")"
V='1:7.4.33-31+ubuntu20.04.1+deb.sury.org+1~local1'
FV=${V#1:}
TS=$(date +%Y%m%d-%H%M)
BK=/root/php74-backup-$TS

echo "== 0. Проверка системы"
[ "$(id -u)" = 0 ] || { echo "Нужен root"; exit 1; }
. /etc/os-release
[ "$VERSION_ID" = "20.04" ] || { echo "Только Ubuntu 20.04, тут $PRETTY_NAME"; exit 1; }
[ "$(dpkg --print-architecture)" = amd64 ] || { echo "Только amd64"; exit 1; }
dpkg -l php7.4-common 2>/dev/null | grep -q '^ii' || { echo "php7.4 не установлен"; exit 1; }
CUR=$(dpkg-query -W -f='${Version}' php7.4-common)
echo "Сейчас php7.4-common $CUR"
case "$CUR" in
  *deb.sury.org*) ;;
  *) echo "Это не сборка Surý ($CUR). Обновление на 7.4.33 сменит версию PHP — остановлено."; exit 1 ;;
esac

echo "== 1. Контрольные суммы"
(cd debs && sha256sum -c --quiet SHA256SUMS) && echo ok

echo "== 2. Какие пакеты обновлять"
PKGS=(); MISSING=()
for p in $(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'php7.4*' 'libapache2-mod-php7.4' 'libphp7.4-embed' 2>/dev/null | awk '$1=="ii"{print $2}'); do
  f=$(ls debs/${p}_${FV}_*.deb 2>/dev/null | head -1)
  if [ -n "$f" ]; then PKGS+=("./$f"); else MISSING+=("$p"); fi
done
printf '  %s\n' "${PKGS[@]}"
if [ ${#MISSING[@]} -gt 0 ]; then
  echo "Нет замены для: ${MISSING[*]} — apt удалил бы их. Остановлено."; exit 1
fi

echo "== 3. Бэкап текущих пакетов и конфигов → $BK"
mkdir -p "$BK/debs"
dpkg -l 'php7.4*' | awk '/^ii/{print $2"="$3}' > "$BK/installed.txt"
tar czf "$BK/etc-php-7.4.tgz" /etc/php/7.4
command -v dpkg-repack >/dev/null || apt-get install -y dpkg-repack
(cd "$BK/debs" && for p in $(cut -d= -f1 "$BK/installed.txt"); do dpkg-repack "$p" >/dev/null; done)
NB=$(ls "$BK/debs" | wc -l); NI=$(wc -l < "$BK/installed.txt")
echo "сохранено пакетов: $NB из $NI"
[ "$NB" -eq "$NI" ] || { echo "Бэкап неполный — без него откатиться не выйдет. Остановлено."; exit 1; }

echo "== 4. Установка (изменённые конфиги не трогаем)"
apt-get install -y --no-install-recommends \
  -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef \
  "${PKGS[@]}"

echo "== 5. Рестарт"
if systemctl list-unit-files php7.4-fpm.service >/dev/null 2>&1; then
  php-fpm7.4 -t
  systemctl restart php7.4-fpm
  echo "php7.4-fpm: $(systemctl is-active php7.4-fpm)"
fi
if dpkg -l libapache2-mod-php7.4 2>/dev/null | grep -q '^ii'; then
  apache2ctl -t && systemctl restart apache2 && echo "apache2: $(systemctl is-active apache2)"
fi
dpkg -l 'php7.4*' | awk '/^ii/{print $2, $3}'

echo "== Готово. Бэкап: $BK. Откат: bash rollback.sh $BK"
echo "Рекомендуется также: session.upload_progress.enabled = 0 в /etc/php/7.4/*/php.ini"
