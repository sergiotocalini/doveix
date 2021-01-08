#!/usr/bin/env ksh
SOURCE_DIR=$(dirname $0)
ZABBIX_DIR=/etc/zabbix
PREFIX_DIR="${ZABBIX_DIR}/scripts/agentd/doveix"
SUDOERS_DIR="/etc/sudoers.d"

DOVEADM_BIN=$(which doveadm)
DOVECOT_BIN=$(which dovecot)
LSOF_BIN=$(which lsof)
PS_BIN=$(which ps)

DOVEIX_URI="${1:-imaps://localhost/}"
DOVEIX_USER="${2:-test@localhost.com}"
DOVEIX_PASS="${3:-xxxxxx}"
CACHE_DIR="${4:-${PREFIX_DIR}/tmp}"
CACHE_TTL="${5:-5}"
DOVEADM_BIN="${DOVEADM_BIN:-/usr/bin/doveadm}"
DOVECOT_BIN="${DOVECOT_BIN:-usr/sbin/dovecot}"
LSOF_BIN="${LSOF_BIN:-/usr/bin/lsof}"
PS_BIN="${PS_BIN:-/usr/bin/ps}"

mkdir -p "${PREFIX_DIR}"

SCRIPT_CONFIG="${PREFIX_DIR}/doveix.conf"
if [[ -f "${SCRIPT_CONFIG}" ]]; then
    SCRIPT_CONFIG="${SCRIPT_CONFIG}.new"
fi

cp -rpv "${SOURCE_DIR}/doveix/doveix.sh"             "${PREFIX_DIR}/"
cp -rpv "${SOURCE_DIR}/doveix/doveix.conf.example"   "${SCRIPT_CONFIG}"
cp -rpv "${SOURCE_DIR}/doveix/zabbix_agentd.conf"    "${ZABBIX_DIR}/zabbix_agentd.d/doveix.conf"
cp -rpv "${SOURCE_DIR}/doveix/doveix.sudoers"        "${SUDOERS_DIR}/doveix"

regex_array[0]="s|DOVEIX_URI=.*|DOVEIX_URI=\"${DOVEIX_URI}\"|g"
regex_array[1]="s|DOVEIX_USER=.*|DOVEIX_USER=\"${DOVEIX_USER}\"|g"
regex_array[2]="s|DOVEIX_PASS=.*|DOVEIX_PASS=\"${DOVEIX_PASS}\"|g"
regex_array[3]="s|CACHE_DIR=.*|CACHE_DIR=\"${CACHE_DIR}\"|g"
regex_array[4]="s|CACHE_TTL=.*|CACHE_TTL=\"${CACHE_TTL}\"|g"
regex_array[5]="s|DOVEADM_BIN=.*|DOVEADM_BIN=\"${DOVEADM_BIN}\"|g"
regex_array[6]="s|DOVECOT_BIN=.*|DOVECOT_BIN=\"${DOVECOT_BIN}\"|g"
regex_array[7]="s|LSOF_BIN=.*|LSOF_BIN=\"${LSOF_BIN}\"|g"
regex_array[8]="s|PS_BIN=.*|PS_BIN=\"${PS_BIN}\"|g"
for index in ${!regex_array[*]}; do
    sed -i "${regex_array[${index}]}" ${SCRIPT_CONFIG}
done
