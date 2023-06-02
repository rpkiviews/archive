#!/bin/sh
# execute rpki-client, tag & sign output, store as signed tarball
# June 2022, Job Snijders <job@sobornost.net>

set -ev
SKEY="/root/.signify/amber.massars.net.sec"
PKEY="/root/.signify/amber.massars.net.pub"
ARCHIVES="/var/www/htdocs/rpkidata"
TMP="$(mktemp -d /tmp/run.XXXXXXXXXX)"

cd /root
rpki-client -vjc 2>&1 | ts %Y%m%dT%H%M%SZ | tee log

TIMESTAMP="$(date '+%Y%m%dT%H%M%SZ')"
DAY="$(date '+%Y/%m/%d')"
mkdir -p "${ARCHIVES}/${DAY}"
cd "${TMP}"
mkdir "rpki-${TIMESTAMP}" && cd "rpki-${TIMESTAMP}"
mkdir output && cd output
cp -r "${PKEY}" .
mv /root/log rpki-client.log
mv /var/db/rpki-client/csv rpki-client.csv
mv /var/db/rpki-client/json rpki-client.json
sha256 -b -h SHA256 *
signify -S -e -s "${SKEY}" -m SHA256 -x SHA256.sig
cd ..
ln -s /var/cache/rpki-client data
mv /var/cache/rpki-client/.rrdp "/tmp/rrdp-${TIMESTAMP}"
mv /var/cache/rpki-client/.rsync"/tmp/rsync-${TIMESTAMP}"
cd ..
gtar hczf "rpki-${TIMESTAMP}-unsigned.tgz" "rpki-${TIMESTAMP}"
rm -rf "rpki-${TIMESTAMP}"
mv "/tmp/rrdp-${TIMESTAMP}" /var/cache/rpki-client/.rrdp
mv "/tmp/rsync-${TIMESTAMP}" /var/cache/rpki-client/.rsync
signify -Sz -s "${SKEY}" \
        -m "rpki-${TIMESTAMP}-unsigned.tgz" \
        -x "${ARCHIVES}/${DAY}/rpki-${TIMESTAMP}.tgz"
rm "rpki-${TIMESTAMP}-unsigned.tgz"
cd "${ARCHIVES}/${DAY}"
rmdir "${TMP}"
sha256 -b "rpki-${TIMESTAMP}.tgz" >> SHA256
signify -S -e -s "${SKEY}" -m SHA256 -x SHA256.sig
