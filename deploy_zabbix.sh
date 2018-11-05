#!/usr/bin/env ksh
SOURCE_DIR=$(dirname $0)
ZABBIX_DIR=/etc/zabbix
PREFIX_DIR="${ZABBIX_DIR}/scripts/agentd/doveix"

DOVEIX_URI="${1:-imaps://localhost/}"
DOVEIX_USER="${2:-test@localhost.com}"
DOVEIX_PASS="${3:-xxxxxx}"
CACHE_DIR="${4:-${PREFIX_DIR}/tmp}"
CACHE_TTL="${5:-5}"

mkdir -p "${PREFIX_DIR}"

SCRIPT_CONFIG="${PREFIX_DIR}/doveix.conf"
if [[ -f "${SCRIPT_CONFIG}" ]]; then
    SCRIPT_CONFIG="${SCRIPT_CONFIG}.new"
fi

cp -rpv "${SOURCE_DIR}/doveix/doveix.sh"             "${PREFIX_DIR}/"
cp -rpv "${SOURCE_DIR}/doveix/doveix.conf.example"   "${SCRIPT_CONFIG}"
cp -rpv "${SOURCE_DIR}/doveix/zabbix_agentd.conf"    "${ZABBIX_DIR}/zabbix_agentd.d/doveix.conf"

regex_array[0]="s|DOVEIX_URI=.*|DOVEIX_URI=\"${DOVEIX_URI}\"|g"
regex_array[1]="s|DOVEIX_USER=.*|DOVEIX_USER=\"${DOVEIX_USER}\"|g"
regex_array[2]="s|DOVEIX_PASS=.*|DOVEIX_PASS=\"${DOVEIX_PASS}\"|g"
regex_array[3]="s|CACHE_DIR=.*|CACHE_DIR=\"${CACHE_DIR}\"|g"
regex_array[4]="s|CACHE_TTL=.*|CACHE_TTL=\"${CACHE_TTL}\"|g"
for index in ${!regex_array[*]}; do
    sed -i "${regex_array[${index}]}" ${SCRIPT_CONFIG}
done
