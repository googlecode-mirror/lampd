#!/bin/bash
# Author:  a950216t <a950216t AT gmail.com>
# Blog:  http://blog.myxnova.com
#
# This script's project home is:
#       http://blog.myxnova.com/lampd.html
#       https://github.com/a950216t/lampd

# Check if user is root
[ $(id -u) != "0" ] && echo "Error: You must be root to run this script" && exit 1

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
clear
printf "
#######################################################################
#    LNMP/LAMP/LANMP for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+    #
# For more information please visit http://blog.myxnova.com/lampd.html  #
#######################################################################
"
[ ! -e "src" ] && mkdir src
cd src
. ../functions/download.sh

if [ -n "`grep 'CentOS release 6' /etc/redhat-release`" ];then
		echo -e "\033[31mYou can install this VPN. \033[0m"
else
        echo -e "\033[31mDoes not support this OS, Please contact the author! \033[0m"
        exit 1
fi

VPN_IP=`../functions/get_public_ip.py`

while :
do
	echo
        read -p "Please input VPN username: " VPN_USER 
        [ -n "$VPN_USER" ] && break 
done

while :
do
	echo
        read -p "Please input VPN password: " VPN_PASS 
        [ -n "$VPN_PASS" ] && break 
done

while :
do
	echo
	read -p "Please input private IP-Range(Default Range: 10.0.2): " iprange
	[ -z "$iprange" ] && iprange="10.0.2"
	if [ -z "`echo $iprange | grep -E "^10\.|^192\.168\.|^172\." | grep -o '^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$'`" ];then
		echo -e "\033[31minput error! Input format: xxx.xxx.xxx\033[0m"
	else
		break
	fi
done
clear

VPN_LOCAL=""$iprange".1"
VPN_REMOTE=""$iprange".2-254"

yum -y groupinstall "Development Tools"
rpm -Uvh http://poptop.sourceforge.net/yum/stable/rhel6/pptp-release-current.noarch.rpm
yum -y install policycoreutils policycoreutils
yum -y install ppp pptpd
yum -y update

echo "1" > /proc/sys/net/ipv4/ip_forward
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
sed -i 's/net.ipv4.tcp_syncookies = 1/#net.ipv4.tcp_syncookies = 1/g' /etc/sysctl.conf

sysctl -p /etc/sysctl.conf

echo "localip $VPN_LOCAL" >> /etc/pptpd.conf # Local IP address of your VPN server
echo "remoteip $VPN_REMOTE" >> /etc/pptpd.conf # Scope for your home network

echo "ms-dns 8.8.8.8" >> /etc/ppp/options.pptpd # Google DNS Primary
echo "ms-dns 209.244.0.3" >> /etc/ppp/options.pptpd # Level3 Primary
echo "ms-dns 208.67.222.222" >> /etc/ppp/options.pptpd # OpenDNS Primary

echo "$VPN_USER pptpd $VPN_PASS *" >> /etc/ppp/chap-secrets

cat >/etc/init.d/iptables <<EOF
#!/bin/sh
#
# iptables	Start iptables firewall
#
# chkconfig: 2345 08 92
# description:	Starts, stops and saves iptables firewall
#
# config: /etc/sysconfig/iptables
# config: /etc/sysconfig/iptables-config
#
### BEGIN INIT INFO
# Provides: iptables
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: start and stop iptables firewall
# Description: Start, stop and save iptables firewall
### END INIT INFO

# Source function library.
. /etc/init.d/functions

IPTABLES=iptables
IPTABLES_DATA=/etc/sysconfig/$IPTABLES
IPTABLES_FALLBACK_DATA=${IPTABLES_DATA}.fallback
IPTABLES_CONFIG=/etc/sysconfig/${IPTABLES}-config
IPV=${IPTABLES%tables} # ip for ipv4 | ip6 for ipv6
[ "$IPV" = "ip" ] && _IPV="ipv4" || _IPV="ipv6"
PROC_IPTABLES_NAMES=/proc/net/${IPV}_tables_names
VAR_SUBSYS_IPTABLES=/var/lock/subsys/$IPTABLES

# only usable for root
[ $EUID = 0 ] || exit 4

if [ ! -x /sbin/$IPTABLES ]; then
    echo -n $"${IPTABLES}: /sbin/$IPTABLES does not exist."; warning; echo
    exit 5
fi

# Old or new modutils
/sbin/modprobe --version 2>&1 | grep -q module-init-tools \
    && NEW_MODUTILS=1 \
    || NEW_MODUTILS=0

# Default firewall configuration:
IPTABLES_MODULES=""
IPTABLES_MODULES_UNLOAD="yes"
IPTABLES_SAVE_ON_STOP="no"
IPTABLES_SAVE_ON_RESTART="no"
IPTABLES_SAVE_COUNTER="no"
IPTABLES_STATUS_NUMERIC="yes"
IPTABLES_STATUS_VERBOSE="no"
IPTABLES_STATUS_LINENUMBERS="yes"
IPTABLES_SYSCTL_LOAD_LIST=""

# Load firewall configuration.
[ -f "$IPTABLES_CONFIG" ] && . "$IPTABLES_CONFIG"

# Netfilter modules
NF_MODULES=($(lsmod | awk "/^${IPV}table_/ {print \$1}") ${IPV}_tables)
NF_MODULES_COMMON=(x_tables nf_nat nf_conntrack) # Used by netfilter v4 and v6

# Get active tables
NF_TABLES=$(cat "$PROC_IPTABLES_NAMES" 2>/dev/null)


rmmod_r() {
    # Unload module with all referring modules.
    # At first all referring modules will be unloaded, then the module itself.
    local mod=$1
    local ret=0
    local ref=

    # Get referring modules.
    # New modutils have another output format.
    [ $NEW_MODUTILS = 1 ] \
	&& ref=$(lsmod | awk "/^${mod}/ { print \$4; }" | tr ',' ' ') \
	|| ref=$(lsmod | grep ^${mod} | cut -d "[" -s -f 2 | cut -d "]" -s -f 1)

    # recursive call for all referring modules
    for i in $ref; do
	rmmod_r $i
	let ret+=$?;
    done

    # Unload module.
    # The extra test is for 2.6: The module might have autocleaned,
    # after all referring modules are unloaded.
    if grep -q "^${mod}" /proc/modules ; then
	modprobe -r $mod > /dev/null 2>&1
	res=$?
	[ $res -eq 0 ] || echo -n " $mod"
	let ret+=$res;
    fi

    return $ret
}

flush_n_delete() {
    # Flush firewall rules and delete chains.
    [ ! -e "$PROC_IPTABLES_NAMES" ] && return 0

    # Check if firewall is configured (has tables)
    [ -z "$NF_TABLES" ] && return 1

    echo -n $"${IPTABLES}: Flushing firewall rules: "
    ret=0
    # For all tables
    for i in $NF_TABLES; do
        # Flush firewall rules.
	$IPTABLES -t $i -F;
	let ret+=$?;

        # Delete firewall chains.
	$IPTABLES -t $i -X;
	let ret+=$?;

	# Set counter to zero.
	$IPTABLES -t $i -Z;
	let ret+=$?;
    done

    [ $ret -eq 0 ] && success || failure
    echo
    return $ret
}

set_policy() {
    # Set policy for configured tables.
    policy=$1

    # Check if iptable module is loaded
    [ ! -e "$PROC_IPTABLES_NAMES" ] && return 0

    # Check if firewall is configured (has tables)
    tables=$(cat "$PROC_IPTABLES_NAMES" 2>/dev/null)
    [ -z "$tables" ] && return 1

    echo -n $"${IPTABLES}: Setting chains to policy $policy: "
    ret=0
    for i in $tables; do
	echo -n "$i "
	case "$i" in
	    security)
        $IPTABLES -t filter -P INPUT $policy \
            && $IPTABLES -t filter -P OUTPUT $policy \
            && $IPTABLES -t filter -P FORWARD $policy \
            || let ret+=1
        ;;
	    raw)
		$IPTABLES -t raw -P PREROUTING $policy \
		    && $IPTABLES -t raw -P OUTPUT $policy \
		    || let ret+=1
		;;
	    filter)
               $IPTABLES -t filter -P INPUT $policy \
		    && $IPTABLES -t filter -P OUTPUT $policy \
		    && $IPTABLES -t filter -P FORWARD $policy \
		    || let ret+=1
		;;
	    nat)
		$IPTABLES -t nat -P PREROUTING $policy \
		    && $IPTABLES -t nat -P POSTROUTING $policy \
		    && $IPTABLES -t nat -P OUTPUT $policy \
		    || let ret+=1
		;;
	    mangle)
	        $IPTABLES -t mangle -P PREROUTING $policy \
		    && $IPTABLES -t mangle -P POSTROUTING $policy \
		    && $IPTABLES -t mangle -P INPUT $policy \
		    && $IPTABLES -t mangle -P OUTPUT $policy \
		    && $IPTABLES -t mangle -P FORWARD $policy \
		    || let ret+=1
		;;
	    *)
	        let ret+=1
		;;
        esac
    done

    [ $ret -eq 0 ] && success || failure
    echo
    return $ret
}

load_sysctl() {
    # load matched sysctl values
    if [ -n "$IPTABLES_SYSCTL_LOAD_LIST" ]; then
        echo -n $"Loading sysctl settings: "
        ret=0
        for item in $IPTABLES_SYSCTL_LOAD_LIST; do
            fgrep $item /etc/sysctl.conf | sysctl -p - >/dev/null
            let ret+=$?;
        done
        [ $ret -eq 0 ] && success || failure
        echo
    fi
    return $ret
}

start() {
    # Do not start if there is no config file.
    [ ! -f "$IPTABLES_DATA" ] && return 6

    # check if ipv6 module load is deactivated
    if [ "${_IPV}" = "ipv6" ] \
	&& grep -qIsE "^install[[:space:]]+${_IPV}[[:space:]]+/bin/(true|false)" /etc/modprobe.conf /etc/modprobe.d/* ; then
	echo $"${IPTABLES}: ${_IPV} is disabled."
	return 150
    fi

    echo -n $"${IPTABLES}: Applying firewall rules: "

    OPT=
    [ "x$IPTABLES_SAVE_COUNTER" = "xyes" ] && OPT="-c"

    $IPTABLES-restore $OPT $IPTABLES_DATA
    if [ $? -eq 0 ]; then
	success; echo
    else
	failure; echo;
	if [ -f "$IPTABLES_FALLBACK_DATA" ]; then
	    echo -n $"${IPTABLES}: Applying firewall fallback rules: "
	    $IPTABLES-restore $OPT $IPTABLES_FALLBACK_DATA
	    if [ $? -eq 0 ]; then
		success; echo
	    else
		failure; echo; return 1
	    fi
	else
	    return 1
	fi
    fi
    
    # Load additional modules (helpers)
    if [ -n "$IPTABLES_MODULES" ]; then
	echo -n $"${IPTABLES}: Loading additional modules: "
	ret=0
	for mod in $IPTABLES_MODULES; do
	    echo -n "$mod "
	    modprobe $mod > /dev/null 2>&1
	    let ret+=$?;
	done
	[ $ret -eq 0 ] && success || failure
	echo
    fi
    
    # Load sysctl settings
    load_sysctl

    touch $VAR_SUBSYS_IPTABLES
    return $ret
}

stop() {
    # Do not stop if iptables module is not loaded.
    [ ! -e "$PROC_IPTABLES_NAMES" ] && return 0

    # Set default chain policy to ACCEPT, in order to not break shutdown
    # on systems where the default policy is DROP and root device is
    # network-based (i.e.: iSCSI, NFS)
    set_policy ACCEPT
    # And then, flush the rules and delete chains
    flush_n_delete
    
    if [ "x$IPTABLES_MODULES_UNLOAD" = "xyes" ]; then
	echo -n $"${IPTABLES}: Unloading modules: "
	ret=0
	for mod in ${NF_MODULES[*]}; do
	    rmmod_r $mod
	    let ret+=$?;
	done
	# try to unload remaining netfilter modules used by ipv4 and ipv6 
	# netfilter
	for mod in ${NF_MODULES_COMMON[*]}; do
	    rmmod_r $mod >/dev/null
	done
	[ $ret -eq 0 ] && success || failure
	echo
    fi
    
    rm -f $VAR_SUBSYS_IPTABLES
    return $ret
}

save() {
    # Check if iptable module is loaded
    [ ! -e "$PROC_IPTABLES_NAMES" ] && return 0

    # Check if firewall is configured (has tables)
    [ -z "$NF_TABLES" ] && return 6

    echo -n $"${IPTABLES}: Saving firewall rules to $IPTABLES_DATA: "

    OPT=
    [ "x$IPTABLES_SAVE_COUNTER" = "xyes" ] && OPT="-c"

    ret=0
    TMP_FILE=$(/bin/mktemp -q $IPTABLES_DATA.XXXXXX) \
	&& chmod 600 "$TMP_FILE" \
	&& $IPTABLES-save $OPT > $TMP_FILE 2>/dev/null \
	&& size=$(stat -c '%s' $TMP_FILE) && [ $size -gt 0 ] \
	|| ret=1
    if [ $ret -eq 0 ]; then
	if [ -e $IPTABLES_DATA ]; then
	    cp -f $IPTABLES_DATA $IPTABLES_DATA.save \
		&& chmod 600 $IPTABLES_DATA.save \
		&& restorecon $IPTABLES_DATA.save \
		|| ret=1
	fi
	if [ $ret -eq 0 ]; then
	    mv -f $TMP_FILE $IPTABLES_DATA \
		&& chmod 600 $IPTABLES_DATA \
		&& restorecon $IPTABLES_DATA \
	        || ret=1
	fi
    fi
    rm -f $TMP_FILE
    [ $ret -eq 0 ] && success || failure
    echo
    return $ret
}

status() {
    if [ ! -f "$VAR_SUBSYS_IPTABLES" -a -z "$NF_TABLES" ]; then
	echo $"${IPTABLES}: Firewall is not running."
	return 3
    fi

    # Do not print status if lockfile is missing and iptables modules are not 
    # loaded.
    # Check if iptable modules are loaded
    if [ ! -e "$PROC_IPTABLES_NAMES" ]; then
	echo $"${IPTABLES}: Firewall modules are not loaded."
	return 3
    fi

    # Check if firewall is configured (has tables)
    if [ -z "$NF_TABLES" ]; then
	echo $"${IPTABLES}: Firewall is not configured. "
	return 3
    fi

    NUM=
    [ "x$IPTABLES_STATUS_NUMERIC" = "xyes" ] && NUM="-n"
    VERBOSE= 
    [ "x$IPTABLES_STATUS_VERBOSE" = "xyes" ] && VERBOSE="--verbose"
    COUNT=
    [ "x$IPTABLES_STATUS_LINENUMBERS" = "xyes" ] && COUNT="--line-numbers"

    for table in $NF_TABLES; do
	echo $"Table: $table"
	$IPTABLES -t $table --list $NUM $VERBOSE $COUNT && echo
    done

    return 0
}

reload() {
    # Do not reload if there is no config file.
    [ ! -f "$IPTABLES_DATA" ] && return 6

    # check if ipv6 module load is deactivated
    if [ "${_IPV}" = "ipv6" ] \
	&& grep -qIsE "^install[[:space:]]+${_IPV}[[:space:]]+/bin/(true|false)" /etc/modprobe.conf /etc/modprobe.d/* ; then
	echo $"${IPTABLES}: ${_IPV} is disabled."
	return 150
    fi

    echo -n $"${IPTABLES}: Trying to reload firewall rules: "

    OPT=
    [ "x$IPTABLES_SAVE_COUNTER" = "xyes" ] && OPT="-c"

    $IPTABLES-restore $OPT $IPTABLES_DATA
    if [ $? -eq 0 ]; then
	success; echo
    else
	failure; echo; echo "Firewall rules are not changed."; return 1
    fi

    # Load additional modules (helpers)
    if [ -n "$IPTABLES_MODULES" ]; then
	echo -n $"${IPTABLES}: Loading additional modules: "
	ret=0
	for mod in $IPTABLES_MODULES; do
	    echo -n "$mod "
	    modprobe $mod > /dev/null 2>&1
	    let ret+=$?;
	done
	[ $ret -eq 0 ] && success || failure
	echo
    fi

    # Load sysctl settings
    load_sysctl

    return $ret
}

restart() {
    [ "x$IPTABLES_SAVE_ON_RESTART" = "xyes" ] && save
    stop
    start
}


case "$1" in
    start)
	[ -f "$VAR_SUBSYS_IPTABLES" ] && exit 0
	start
	RETVAL=$?
	;;
    stop)
	[ "x$IPTABLES_SAVE_ON_STOP" = "xyes" ] && save
	stop
	RETVAL=$?
	;;
    restart|force-reload)
	restart
	RETVAL=$?
	;;
    reload)
	[ -e "$VAR_SUBSYS_IPTABLES" ] && reload
	RETVAL=$?
	;;      
    condrestart|try-restart)
	[ ! -e "$VAR_SUBSYS_IPTABLES" ] && exit 0
	restart
	RETVAL=$?
	;;
    status)
	status
	RETVAL=$?
	;;
    panic)
	set_policy DROP
	RETVAL=$?
        ;;
    save)
	save
	RETVAL=$?
	;;
    *)
	echo $"Usage: ${IPTABLES} {start|stop|reload|restart|condrestart|status|panic|save}"
	RETVAL=2
	;;
esac

exit $RETVAL
EOF

service iptables start
service iptables restart
echo "iptables -t nat -A POSTROUTING -s $iprange.0/24 -o eth0 -j MASQUERADE" >> /etc/rc.local
iptables -t nat -A POSTROUTING -s ${iprange}.0/24 -o eth0 -j MASQUERADE
iptables -I INPUT -p tcp --dport 1723 -j ACCEPT
service iptables save
service iptables restart

service pptpd restart
chkconfig pptpd on

echo -e '\E[37;44m'"\033[1m You can now connect to your VPN via your external IP ($VPN_IP)\033[0m"
echo "Server Local IP:$iprange.1"
echo "Client Remote IP Range:$iprange.2-$iprange.254"
echo -e '\E[37;44m'"\033[1m Username: $VPN_USER\033[0m"
echo -e '\E[37;44m'"\033[1m Password: $VPN_PASS\033[0m"