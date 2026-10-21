# php7.4 for Ubuntu 20.04 with the php2shell fix (CVE-2026-109618 / CVE-2026-109619)

**[Русский — ниже](#русский)**

Unofficial rebuild of Ondřej Surý's `php7.4 1:7.4.33-31` for **Ubuntu 20.04 (focal), amd64**.

On 2026-10-21 Surý shipped `1:7.4.33-31`, which backports the fix for the two critical PHP RCEs
known as *php2shell* (changelog: *"Backported from 8.2.35 — [CVE-2026-109618, CVE-2026-109619]: Avoid state
corruption via bailout"*). But `ppa:ondrej/php` stopped publishing for focal in 2025, so 20.04 servers running
Surý's php7.4 get no update. This repo rebuilds the unchanged jammy source package for focal.

> ⚠️ **No warranty.** Not signed or endorsed by Surý or the PHP project. PHP 7.4 is end-of-life — treat this
> as a stopgap and plan a move to a supported PHP. Review the scripts before running them as root.

## Do you need this?

| System | What to do |
|---|---|
| Ubuntu 20.04 amd64, php7.4 from `ppa:ondrej/php` (`1:7.4.33-NN+ubuntu20.04.1+deb.sury.org+1`) | **use this** |
| Ubuntu 20.04, stock php7.4 (`7.4.3-4ubuntu2.x`) | not this — Ubuntu Pro / esm-infra ships the fix (USN-8948-2) |
| Ubuntu 22.04 / 24.04, Debian 11 / 12 | not this — Surý ships `-31` officially: `apt update && apt install --only-upgrade 'php7.4*'` |
| Ubuntu 18.04, arm64 | not built |

## Packages

All 38 binary packages built from the `php7.4` source, version `1:7.4.33-31+ubuntu20.04.1+deb.sury.org+1~local1`:

| Group | Packages |
|---|---|
| Core | `php7.4` (metapackage), `php7.4-common`, `php7.4-cli`, `php7.4-json`, `php7.4-opcache`, `php7.4-readline`, `php7.4-dev` |
| SAPI | `php7.4-fpm`, `libapache2-mod-php7.4`, `php7.4-cgi`, `php7.4-litespeed`, `php7.4-phpdbg`, `libphp7.4-embed` |
| Databases | `php7.4-mysql`, `php7.4-pgsql`, `php7.4-sqlite3`, `php7.4-odbc`, `php7.4-interbase`, `php7.4-sybase`, `php7.4-dba` |
| Text, XML | `php7.4-mbstring`, `php7.4-intl`, `php7.4-xml`, `php7.4-xsl`, `php7.4-xmlrpc`, `php7.4-soap`, `php7.4-tidy`, `php7.4-enchant`, `php7.4-pspell` |
| Other | `php7.4-curl`, `php7.4-gd`, `php7.4-zip`, `php7.4-bz2`, `php7.4-bcmath`, `php7.4-gmp`, `php7.4-imap`, `php7.4-ldap`, `php7.4-snmp` |

`php7.4-common` also carries the built-in extensions (ctype, exif, fileinfo, ftp, iconv, pdo, mysqlnd, phar,
posix, sockets, tokenizer, …).

**Not included** — extensions built from their own source packages: `php7.4-redis`, `-imagick`, `-memcached`,
`-apcu`, `-igbinary`, `-xdebug`, `-mongodb`, `-amqp`, etc. They don't contain the vulnerable code, need no
update and keep working with this build (same PHP API `20190902`).

## Install

Download `php74-31-focal-amd64.tgz` from [Releases](../../releases), then as root:

```bash
sha256sum php74-31-focal-amd64.tgz        # compare with the release notes
tar xzf php74-31-focal-amd64.tgz && cd php74-31-focal-amd64
bash install.sh
```

`install.sh`:
1. refuses to run unless it is Ubuntu 20.04 amd64 with Surý's php7.4;
2. verifies `SHA256SUMS`;
3. upgrades **only the php7.4-\* packages you already have**, and stops if one of them has no replacement in
   the bundle (otherwise apt would remove it);
4. backs up the current packages (`dpkg-repack`) and `/etc/php/7.4` to `/root/php74-backup-<date>` and stops
   if the backup is incomplete;
5. installs keeping your modified config files (`--force-confold`; `php.ini` is ucf-managed and also kept);
6. runs `php-fpm7.4 -t`, restarts `php7.4-fpm` (and `apache2` if `libapache2-mod-php7.4` is installed).

Rollback: `bash rollback.sh /root/php74-backup-<date>`.

## Verify

**On the server** (read-only, safe on production):

```bash
sudo bash check-installed.sh
# OK   php7.4-fpm package 1:7.4.33-31+ubuntu20.04.1+deb.sury.org+1~local1
# OK   /usr/sbin/php-fpm7.4 sha256 matches this build
# OK   running php-fpm processes use the new binary
# RESULT: patched build is installed and running
```

It checks the package version, the sha256 of `/usr/sbin/php-fpm7.4` (the Zend engine and multipart parser are
linked into it) and that no php-fpm / apache2 process still runs the old, deleted binary.

**That the fix is in the build** (throwaway container, *not* on a server — it installs packages):

```bash
cd php74-31-focal-amd64
docker run --rm --platform linux/amd64 -v "$PWD/debs:/o:ro" -v "$PWD/verify-fix.sh:/t.sh:ro" ubuntu:20.04 bash /t.sh ours
# SESSION: []                         <- patched
docker run --rm --platform linux/amd64 -v "$PWD/verify-fix.sh:/t.sh:ro" ubuntu:20.04 bash /t.sh stock
# SESSION: ["upload_progress_mark"]   <- unpatched Ubuntu 7.4.3, for comparison
```

The patch makes session upload progress a no-op (`ext/session/session.c`: `if (!PS(rfc1867_enabled) || true)`),
so with `session.upload_progress.enabled=1` an unpatched PHP writes `upload_progress_*` into the session and the
patched one doesn't. This is a marker of the patch, not an exploit test.

Extensions from separate source packages (`php7.4-redis`, `-imagick`, `-memcached`, …) are untouched and keep
working — the PHP API (`20190902`) is the same.

Also recommended (official advice, keep it after patching):
`session.upload_progress.enabled = 0` in `/etc/php/7.4/*/php.ini`.

## What was tested

- Built in a clean `ubuntu:20.04` amd64 container (`build/build.sh`); package test suite skipped (`nocheck`).
- Clean focal install: `php -v`, `php-fpm7.4 -t`, GET / multipart upload / urlencoded POST through FPM
  (`build/smoke.sh`).
- `install.sh` + `rollback.sh` in a container; one production server upgraded from `-16` to `-31` (~40 FPM
  pools, sites OK).
- Marker test `verify-fix.sh`: stock 7.4.3 → `["upload_progress_mark"]`, this build → `[]` (see [Verify](#verify)).
- `check-installed.sh` on the production server: all OK.
- **Not** tested against an exploit.

## Build it yourself

```bash
docker run --rm --platform linux/amd64 -v "$PWD/build/build.sh:/build.sh:ro" -v "$PWD/out:/out" \
  ubuntu:20.04 bash /build.sh
```

Source: `php7.4_7.4.33-31+ubuntu22.04.1+deb.sury.org+1.dsc` from
[ppa:ondrej/php](https://launchpad.net/~ondrej/+archive/ubuntu/php). The only change is a focal changelog
entry (`~local1`). Surý's `php-common` / `dh-php` from packages.sury.org (jammy, arch:all) are installed in the
build container only — `debian/rules` needs `/usr/lib/php/php-common.mk`.

## Links

- [GHSA-w8hw-w9fx-j79w](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w) (CVE-2026-109618),
  [GHSA-6wmf-4rv5-p3rp](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp) (CVE-2026-109619)
- [CISA alert](https://www.cisa.gov/news-events/alerts/2026/10/21/critical-vulnerabilities-php-require-immediate-patching)

---

## Русский

Неофициальная пересборка `php7.4 1:7.4.33-31` от Ondřej Surý под **Ubuntu 20.04 (focal), amd64** — с фиксом
двух критических RCE «php2shell» (CVE-2026-109618, CVE-2026-109619). Surý выпустил `-31` 21.10.2026 только
для 22.04/24.04 — focal из `ppa:ondrej/php` убран в 2025-м. Здесь — тот же исходник, собранный под focal.

> ⚠️ **Без гарантий**, не подписано Surý. PHP 7.4 — EOL: это временная мера, планируйте переезд.

**Пакеты:** все 38 бинарных пакетов исходника `php7.4` — ядро, SAPI (`fpm`, `libapache2-mod-php7.4`, `cgi`,
`litespeed`, `phpdbg`, `embed`) и модули (`mysql`, `pgsql`, `sqlite3`, `curl`, `gd`, `intl`, `mbstring`, `xml`,
`zip`, `soap`, `imap`, `ldap` и др.), полный список — в таблице [Packages](#packages). Расширения из отдельных
пакетов (`redis`, `imagick`, `memcached`, `apcu`, `xdebug`…) не входят: обновлять их не нужно, они продолжат работать.

**Подходит:** Ubuntu 20.04 amd64 с php7.4 из репозитория Surý. Для штатного php7.4 Ubuntu — Ubuntu Pro
(USN-8948-2). Для 22.04 / 24.04 / Debian — просто `apt upgrade` из репозитория Surý.

**Установка** (root): скачать `php74-31-focal-amd64.tgz` из Releases, сверить sha256, затем
`tar xzf php74-31-focal-amd64.tgz && cd php74-31-focal-amd64 && bash install.sh`.

Скрипт проверит систему, обновит только уже установленные пакеты php7.4-\* (и остановится, если какому-то
нет замены), сделает бэкап (`/root/php74-backup-<дата>`), сохранит ваши конфиги и перезапустит FPM.
Откат: `bash rollback.sh /root/php74-backup-<дата>`.

**Проверка** на сервере (только чтение): `sudo bash check-installed.sh` — версия пакета, sha256 бинарника,
что FPM перезапущен. Что фикс есть в сборке — `verify-fix.sh` в контейнере, см. [Verify](#verify).

Рекомендуется также `session.upload_progress.enabled = 0` в php.ini.

## License

Scripts: MIT. Packages: PHP License / respective upstream licenses, as in the original Debian packaging.
