#!/bin/bash
function SYNRECV {
/usr/sbin/ss -s |grep 'synrecv'|awk -F, '{print $4}'|awk '{print $2}'
}
function ESTAB {
/usr/sbin/ss -ant | awk '{++s[$1]} END {for(k in s) print k,s[k]}' | grep 'ESTAB' | awk '{print $2}'
}
function FINWAIT1 {
/usr/sbin/ss -ant|  grep 'FIN-WAIT-1'|wc -l
}
function FINWAIT2 {
/usr/sbin/ss -ant| grep 'FIN-WAIT-2' | wc -l
}
function TIMEWAIT {
/usr/sbin/ss -ant | grep 'TIME-WAIT' | wc -l
}
function LASTACK {
/usr/sbin/ss -ant | grep 'LAST-ACK' | wc -l
}
function LISTEN {
/usr/sbin/ss -ant | grep 'LISTEN' | wc -l
}
$1