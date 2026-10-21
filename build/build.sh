#!/bin/bash
# Сборка php7.4 1:7.4.33-31 (Surý, фикс CVE-2026-109618/109619) под Ubuntu 20.04 focal amd64.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
V=7.4.33-31+ubuntu22.04.1+deb.sury.org+1
BASE=https://launchpad.net/~ondrej/+archive/ubuntu/php/+files

apt-get update
apt-get install -y --no-install-recommends devscripts equivs build-essential ca-certificates curl xz-utils lsb-release fakeroot software-properties-common
# debhelper 13 есть в focal-backports — пригодится, если пакет требует compat 13
add-apt-repository -y "deb http://archive.ubuntu.com/ubuntu focal-backports main universe"
apt-get update

# php-common.mk (php-defaults) и dh-php — свежие arch:all из Surý jammy, только для сборки
SURY=https://packages.sury.org/php
mkdir -p /work/helpers && cd /work/helpers
curl -sf $SURY/dists/jammy/main/binary-amd64/Packages.gz | gunzip > Packages
for p in php-common dh-php; do
  f=$(awk -v p="$p" '$0=="Package: "p{x=1} x&&/^Filename:/{print $2; exit}' Packages)
  curl -sfO "$SURY/$f"
done
apt-get install -y --no-install-recommends ./*.deb
ls -la /usr/lib/php/php-common.mk

mkdir -p /work/src && cd /work/src
dget -u -d "$BASE/php7.4_$V.dsc"
dpkg-source -x "php7.4_$V.dsc" php7.4
cd php7.4
grep -nE 'Build-Depends|debhelper' debian/control | head

mk-build-deps -i -r -t 'apt-get -y --no-install-recommends -t focal-backports' debian/control || \
  mk-build-deps -i -r -t 'apt-get -y --no-install-recommends' debian/control

DEBEMAIL=build@local DEBFULLNAME='local build' \
  dch -b -v "1:7.4.33-31+ubuntu20.04.1+deb.sury.org+1~local1" -D focal "Rebuild of Surý 7.4.33-31 (CVE-2026-109618, CVE-2026-109619) for focal."

DEB_BUILD_OPTIONS="parallel=$(nproc) nocheck" dpkg-buildpackage -us -uc -b
mkdir -p /out && cp ../*.deb ../*.buildinfo ../*.changes /out/
ls -la /out
