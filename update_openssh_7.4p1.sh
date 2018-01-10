#!/bin/bash
# -*- coding:utf-8 -*-
#################################################################
######    update openssl openssh script                 #########
#####             Author:insqur                             #####
######           Date:2017/08/15                            #####
######        LastModified:2018/01/10                     #######
####  Warning:start telnet service before use the script    #####
#################################################################
check_environment()
{
# Determine whether the current system installed gcc compiler tools
openssl_version="openssl-1.0.1e"
openssh_version="openssh-7.4p1"

CUR_DIR=$(pwd)
DATE=$(date +%Y%m%d)
# OS TYPE
Distributor=`cat /etc/issue | sed -n '1p;1q' | cut -c -6`

# Determine whether the root user
userid=`id -u`
if [ "$userid" -ne 0 ]; then
    echo "sorry,only root can execute the script. "
    exit
fi

#check openssh.tar.gz exists
if [ ! -e ${openssh_version}.tar.gz ]; then
    echo "${CUR_DIR}/${openssh_version}.tar.gz not exists"
    exit
fi

# zlib-devel need be installed, Otherwise, the software will install failure
if ! rpm -qa|grep zlib-devel &>/dev/null; then
    echo "zlib-devel is not installed,pls run:yum install zlib-devel"
    exit
fi

# pam-devel need be installed, Otherwise, the software will install failure
if ! rpm -qa|grep pam-devel &>/dev/null; then
    echo "pam-devel is not installed,pls run:yum install pam-devel"
    exit
fi

# openssl-devel need be installed, Otherwise, the software will install failure
if ! rpm -qa|grep openssl-devel &>/dev/null; then
    echo "openssl-devel is not installed,pls run:yum install openssl-devel"
    exit
fi

# Determine whether to install gcc package
which gcc &>/dev/null
RETVAL2=$?
if [ $RETVAL2 -ne 0 ]; then
    echo "gcc is not installed,pls run:yum install gcc"
    exit
fi

#  Check whether to open the telnet service
netstat -tnlp | grep -w 23
RETVAL3=$?
if [ $RETVAL3 -eq 0 ]; then
    echo "telnet service is running------------[yes]"
else
    echo "telnet service is not running--------[no]"
#   exit
fi

#Check iptables status
/sbin/service iptables status 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "iptables is started,pls stop or permit telnet 23 port"
#   exit
fi
}

ssh_update()
{
###########install openssl ##################

############# install openssh ##############

if [ -e /etc/ssh ]; then
    mv /etc/ssh /etc/ssh_$DATE
fi

# remove openssh*.rpm if exists
if rpm -qa | grep openssh &> /dev/null;   then
    rpm -e --nodeps `rpm -qa |grep openssh`
fi

# Install openssh
tar -zxvf "${openssh_version}.tar.gz" > /dev/null
cd $openssh_version
./configure --prefix=/usr/local/openssh74 --sysconfdir=/etc/ssh --with-pam --with-ssl-dir=/usr/local/openssl --with-md5-passwords --mandir=/usr/share/man --with-zlib=/usr/local/zlib
RETVAL9=$?
if [ $RETVAL9 -ne 0 ]; then
    echo "Configure openssh has encountered an error"
    exit
fi

make -j4
RETVAL10=$?
if [ $RETVAL10 -ne 0 -a $RETVAL10 -ne 0 ]; then
        echo "make openssh has encountered an error"
        exit
fi

make install

if [ $Distributor ]; then
    cp -p  contrib/redhat/sshd.init /etc/init.d/sshd
    chmod +x /etc/init.d/sshd
    chkconfig --add sshd
fi

# Modify /etc/ssh/sshd_config
# Backup /etc/ssh/sshd_config
cp -p /etc/ssh/sshd_config /etc/ssh/sshd_config_bak
sed -i '/^#PermitRootLogin/s/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# New ssh sshd ssh-keygen
if [ -e /usr/bin/ssh ]; then
    mv /usr/bin/ssh /usr/bin/ssh_bak
fi

cp /usr/local/openssh74/bin/ssh /usr/bin/ssh

if [ -e /usr/sbin/sshd ]; then
    mv /usr/sbin/sshd /usr/sbin/sshd_bak
fi
cp /usr/local/openssh74/sbin/sshd /usr/sbin/sshd

if [ -e /usr/bin/ssh-keygen ]; then
    mv /usr/bin/ssh-keygen /usr/bin/ssh-keygen_bak
fi
cp /usr/local/openssh74/bin/ssh-keygen /usr/bin/ssh-keygen

# Start sshd process
service sshd start


echo "#########################################################"
echo "################ openssh install success  ################"
echo "#########################################################"
echo "###############   ssh version     ####################### "
echo "######################################################### "
ssh -V
echo "######################################################### "
}

disable_telnet()
{
# Disable telnet service
if netstat -tnlp | grep -w 22 &> /dev/null; then
sed -i '/disable/s/no/yes/' /etc/xinetd.d/telnet
service xinetd restart
fi
}

read -p "Are you using telnet[Y/N]?" ANSWER
case $ANSWER in
Y | y)
   echo "Check environment"
   check_environment
   ssh_update 2>&1 | tee -a /tmp/update.log ;;
N | n)
   echo "It is dangerous,Pls install telnet-server firstly!";;
*)
   echo "Wrong choice,Pls input again";;
esac
