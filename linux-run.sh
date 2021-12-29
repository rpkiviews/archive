#!/bin/sh
# execute rpki-client, tag & sign output, store as ZFS snapshot,
# store as signed tarball
#
# December 2020
#
# Job Snijders <job@sobornost.net>

set -e

SKEY="/home/job/.signify/josephine.sobornost.net.sec"
ARCHIVES="/var/www/html/josephine.sobornost.net/rpkidata"
SNAPSHOT="/tank/rpkirepositories"

cd "${SNAPSHOT}"
sudo chown -R _rpki-client output

timeout -k 10m 20m \
        sudo \
        rpki-client -e rsync -v -jc \
                -d "${SNAPSHOT}/data" \
                "${SNAPSHOT}/output" 2>&1 \
        | ts %Y%m%dT%H%M%SZ \
        | sudo tee output/log

# clean up empty directories, set permissions
cd data/
sudo find . ! -name . -empty -type d -delete
sudo chmod -R a+rX,a+r .

# process output files
cd ../output/
sudo chown -R job .
mv log rpki-client.log
mv csv rpki-client.csv
mv json rpki-client.json
sha256sum --tag rpki-client.log rpki-client.csv rpki-client.json > SHA256
signify-openbsd -S -e -s "${SKEY}" -m SHA256 -x SHA256.sig

TIMESTAMP="$(date '+%Y%m%dT%H%M%SZ')"
DAY="$(date '+%Y/%m/%d')"

sudo zfs snapshot "tank/rpkirepositories@${TIMESTAMP}"

mkdir -p "${ARCHIVES}/${DAY}"

cd "${ARCHIVES}/${DAY}/"

ln -s "${SNAPSHOT}/.zfs/snapshot/${TIMESTAMP}" "rpki-${TIMESTAMP}"

sudo tar hcz --exclude=run.sh -f "rpki-${TIMESTAMP}-unsigned.tgz" "rpki-${TIMESTAMP}"

rm "rpki-${TIMESTAMP}"

# sign tgz file
signify-openbsd -Sz -s "${SKEY}" \
        -m "rpki-${TIMESTAMP}-unsigned.tgz" \
        -x "rpki-${TIMESTAMP}.tgz"

sudo rm "rpki-${TIMESTAMP}-unsigned.tgz"

chmod -w "rpki-${TIMESTAMP}.tgz"
sha256sum --tag "rpki-${TIMESTAMP}.tgz" >> SHA256
signify-openbsd -S -e -s "$SKEY" -m SHA256 -x SHA256.sig
