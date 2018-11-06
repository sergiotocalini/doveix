#!/usr/bin/env ksh
PATH=/usr/local/bin:${PATH}
IFS_DEFAULT="${IFS}"

#################################################################################

#################################################################################
#
#  Variable Definition
# ---------------------
#
APP_NAME=$(basename $0)
APP_DIR=$(dirname $0)
APP_VER="1.0.0"
APP_WEB="http://www.sergiotocalini.com.ar/"
PID_FILE="/var/run/keepalived.pid"
TIMESTAMP=`date '+%s'`
DOVEIX_URI="imap://localhost/"
CACHE_DIR=${APP_DIR}/tmp
CACHE_TTL=10                                      # IN MINUTES
#
#################################################################################

#################################################################################
#
#  Load Oracle Environment
# -------------------------
#
[ -f ${APP_DIR}/${APP_NAME%.*}.conf ] && . ${APP_DIR}/${APP_NAME%.*}.conf

#
#################################################################################

#################################################################################
#
#  Function Definition
# ---------------------
#
usage() {
    echo "Usage: ${APP_NAME%.*} [Options]"
    echo ""
    echo "Options:"
    echo "  -a            Arguments to the section."
    echo "  -h            Displays this help message."
    echo "  -j            Jsonify output."
    echo "  -s            Select the section (service, account, etc. )."
    echo "  -v            Show the script version."
    echo ""
    echo "Please send any bug reports to sergiotocalini@gmail.com"
    exit 1
}

version() {
    echo "${APP_NAME%.*} ${APP_VER}"
    exit 1
}

zabbix_not_support() {
    echo "ZBX_NOTSUPPORTED"
    exit 1
}

users() {
    params=( ${@} )

    if [[ ${params[0]} =~ (connected|clients) ]]; then
	data=`doveadm who -1 2>/dev/null`
	if [[ ${params[1]} == 'connected' ]]; then
	    res=`echo "${data}" | awk '{print $1}' | sort | uniq | wc -l`
	elif [[ ${params[1]} == 'clients' ]]; then
	    res=`echo "${data}" | awk '{print $4}' | sort | uniq | wc -l`
	fi	
    elif [[ ${params[0]} == 'domains' ]]; then
	res=`doveadm user "*" 2>/dev/null | cut -d@ -f2 | sort | uniq | wc -l`
    elif [[ ${params[0]} == 'total' ]]; then
	res=`doveadm user "*" 2>/dev/null | sort | uniq | wc -l`
    else
	res=`doveadm user "*" 2>/dev/null | sort | uniq`
    fi
    echo ${res:-0}
    return 0    
}

service() {
    params=( ${@} )
    pattern='^(([a-z]{3,5})://)?((([^:\/]+)(:([^@\/]*))?@)?([^:\/?]+)(:([0-9]+))?)(\/[^?]*)?(\?[^#]*)?(#.*)?$'
    [[ "${DOVEIX_URI}" =~ $pattern ]] || return 1
    regex_match=( "${.sh.match[@]:-${BASH_REMATCH[@]:-${match[@]}}}" )
    
    if [[ ${params[0]} =~ (uptime|listen|cert) ]]; then
	pid=`sudo lsof -Pi :${regex_match[10]:-${regex_match[2]}} -sTCP:LISTEN -t 2>/dev/null`
	rcode="${?}"
	if [[ -n ${pid} ]]; then
	    if [[ ${params[0]} == 'uptime' ]]; then
		res=`sudo ps -p ${pid} -o etimes -h 2>/dev/null`
	    elif [[ ${params[0]} == 'listen' ]]; then
		[[ ${rcode} == 0 && -n ${pid} ]] && res=1
	    elif [[ ${params[0]} == 'cert' ]]; then
		cert_text=`openssl s_client -connect "${regex_match[3]}:${regex_match[10]:-${regex_match[2]}}" </dev/null 2>/dev/null`
		if [[ ${params[1]} == 'expires' ]]; then
		    date=`echo "${cert_text}" | openssl x509 -noout -enddate 2>/dev/null | cut -d'=' -f2`
		    res=$((($(date -d "${date}" +'%s') - $(date +'%s'))/86400))
		elif [[ ${params[1]} == 'after' ]]; then
		    date=`echo "${cert_text}" | openssl x509 -noout -enddate 2>/dev/null | cut -d'=' -f2`
		res=`date -d "${date}" +'%s' 2>/dev/null`
		elif [[ ${params[1]} == 'before' ]]; then
		    date=`echo "${cert_text}" | openssl x509 -noout -startdate 2>/dev/null | cut -d'=' -f2`
		    res=`date -d "${date}" +'%s' 2>/dev/null`
		fi
	    fi
	fi
    elif [[ ${params[0]} == 'version' ]]; then
	res=`dovecot --version 2>/dev/null`
    fi
    echo ${res:-0}
    return 0
}

account() {
    operation="${1:-login}"
    params=( "${@:2}" )
    
    [[ -z ${DOVEIX_URI} || -z ${DOVEIX_USER} || -z ${DOVEIX_PASS} ]] && return 1
    
    if [[ ${operation} =~ (login|LOGIN|connect|CONNECT|conn|CONN) ]]; then
	curl -s -o /dev/null --insecure --url "${DOVEIX_URI}" --user "${DOVEIX_USER}:${DOVEIX_PASS}" 2>/dev/null
	rcode="${?}"
	[[ ${rcode} == 0 ]] && rval=1
    elif [[ ${operation} =~ (examine|EXAMINE) ]]; then
	res=`curl -s --insecure --url "${DOVEIX_URI}" --user "${DOVEIX_USER}:${DOVEIX_PASS}" --request "EXAMINE ${params[0]:-INBOX}" 2>/dev/null`
	rcode="${?}"
	rval=`echo "${res}" | grep -E "^*.*EXISTS" | grep -oE '[0-9]+'`
    fi
    echo "${rval:-0}"
    return "${rcode:-0}"
}

#
#################################################################################

#################################################################################
while getopts "s::a:sj:uphvt:" OPTION; do
    case ${OPTION} in
	h)
	    usage
	    ;;
	s)
	    SECTION="${OPTARG}"
	    ;;
        j)
            JSON=1
            IFS=":" JSON_ATTR=( ${OPTARG} )
	    IFS="${IFS_DEFAULT}"
            ;;
	a)
	    param="${OPTARG//p=}"
	    [[ -n ${param} ]] && ARGS[${#ARGS[*]}]="${param}"
	    ;;
	v)
	    version
	    ;;
        \?)
            exit 1
            ;;
    esac
done

if [[ "${SECTION}" == "service" ]]; then
    rval=$( service "${ARGS[@]}" )  
elif [[ "${SECTION}" == "users" ]]; then
    rval=$( users "${ARGS[@]}" )
elif [[ "${SECTION}" == "account" ]]; then
    rval=$( account "${ARGS[@]}" )
else
    zabbix_not_support
fi
rcode="${?}"

if [[ ${JSON} -eq 1 ]]; then
    echo '{'
    echo '   "data":['
    count=1
    while read line; do
	if [[ ${line} != '' ]]; then
            IFS="|" values=(${line})
            output='{ '
            for val_index in ${!values[*]}; do
		output+='"'{#${JSON_ATTR[${val_index}]:-${val_index}}}'":"'${values[${val_index}]}'"'
		if (( ${val_index}+1 < ${#values[*]} )); then
                    output="${output}, "
		fi
            done
            output+=' }'
	    if (( ${count} < `echo ${rval}|wc -l` )); then
		output="${output},"
            fi
            echo "      ${output}"
	fi
        let "count=count+1"
    done < <(echo "${rval}")
    echo '   ]'
    echo '}'
else
    echo "${rval:-0}"
fi

exit ${rcode}
