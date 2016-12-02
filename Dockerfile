FROM centos:centos7
MAINTAINER sergei <sergey888@inbox.ru>

RUN yum update -y
RUN yum install -y epel-release
RUN yum install lame fail2ban wget which patch git kernel-headers gcc gcc-c++ cpp ncurses ncurses-devel libxml2 libxml2-devel sqlite sqlite-devel\
 openssl-devel newt-devel kernel-devel libuuid-devel net-snmp-devel xinetd tar jansson-devel make bzip2 -y

WORKDIR /usr/src

RUN wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-13.13.0.tar.gz
RUN tar xvfz asterisk-13.13.0.tar.gz 1> /dev/null
WORKDIR /usr/src/asterisk-13.13.0

RUN ./contrib/scripts/install_prereq install 1> /dev/null
RUN ./contrib/scripts/get_mp3_source.sh 1> /dev/null


# Configure
RUN ./configure --libdir=/usr/lib64 --with-pjproject-bundled 1> /dev/null
# Remove the native build option
# from: https://wiki.asterisk.org/wiki/display/AST/Building+and+Installing+Asterisk
RUN make menuselect.makeopts
RUN menuselect/menuselect \
  --disable BUILD_NATIVE \
  --enable format_mp3 \
  --enable chan_sip \
  --enable res_snmp \
  --enable res_http_websocket \
  --enable cdr_mysql \
  --enable app_mysql \
menuselect.makeopts

# Continue with a standard make.
RUN make 1> /dev/null
RUN make install 1> /dev/null
RUN make samples 1> /dev/null
WORKDIR /

RUN useradd -m asterisk -s /sbin/nologin
RUN chown asterisk:asterisk /var/run/asterisk
RUN chown -R asterisk:asterisk /etc/asterisk/
RUN chown -R asterisk:asterisk /var/{lib,log,spool}/asterisk
RUN chown -R asterisk:asterisk /usr/lib64/asterisk/

WORKDIR /tmp
RUN wget http://asterisk.hosting.lv/bin/codec_g729-ast130-gcc4-glibc2.2-x86_64-core2.so
RUN mv codec_g729-ast130-gcc4-glibc2.2-x86_64-core2.so codec_g729a.so && cp codec_g729a.so /usr/lib64/asterisk/modules/

# Update max number of open files.
RUN sed -i -e 's/# MAXFILES=/MAXFILES=/' /usr/sbin/safe_asterisk

#Fail2Ban
RUN sed -i 's/messages => notice,warning,error/messages => notice,warning,error,security/' /etc/asterisk/logger.conf
RUN sed -i '/\[general\]/ a dateformat=%F %T'  /etc/asterisk/logger.conf
RUN cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
RUN sed -i '/\[asterisk\]/ a enable=true \nbantime=86400'  /etc/fail2ban/jail.local
RUN fail2ban-client reload


CMD /usr/sbin/asterisk -f -U asterisk -G asterisk -vvvg -c
