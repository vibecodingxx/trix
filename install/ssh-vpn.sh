#!/bin/bash
# =========================================
# Quick Setup | SSHVPN Manager
# Edition : Stable Edition V1.0
# BY : XCODEX
# (C) Copyright 2025 - 2026
# =========================================

# initializing var
export DEBIAN_FRONTEND=noninteractive
# public ip
MYIP=$(curl -s ipv4.icanhazip.com || curl -s ipinfo.io/ip || curl -s ifconfig.me)
MYIP2="s/xxxxxxxxx/$MYIP/g";
NET=$(ip -o $ANU -4 route show to default | awk '{print $5}');
source /etc/os-release
ver=$VERSION_ID

# Detail Perusahaan / Certificate Info
country="MY"                   # ISO country code
state="Johor"               # State / Province
locality="Kempas"          # City / Locality
organization="Hawau"
organizationalunit="IT Department"
commonname="anal"         # Common Name (domain / server)
email="123@gmail.com"    # Admin Email

# simple password minimal
wget -O /etc/pam.d/common-password "https://raw.githubusercontent.com/vibecodingxx/trix/main/others/password"
chmod +x /etc/pam.d/common-password

# root
cd

# Edit file /etc/systemd/system/rc-local.service
cat > /etc/systemd/system/rc-local.service <<-END
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local
[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99
[Install]
WantedBy=multi-user.target
END

# nano /etc/rc.local
cat > /etc/rc.local <<-END
#!/bin/sh -e
# rc.local
# By default this script does nothing.
exit 0
END

# access vps
chmod +x /etc/rc.local

# enable rc local
systemctl enable rc-local
systemctl start rc-local.service

# update packages
apt update -y
apt upgrade -y
apt dist-upgrade -y
apt-get remove --purge ufw firewalld -y
apt-get remove --purge exim4 -y

# install wget and curl
apt -y install wget curl net-tools

# set GMT +8
ln -fs /usr/share/zoneinfo/Asia/Kuala_Lumpur /etc/localtime

# set locale
sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config

# install req packages
#apt-get --reinstall --fix-missing install -y bzip2 gzip coreutils wget screen rsyslog iftop htop net-tools zip unzip wget net-tools curl nano sed screen gnupg gnupg1 bc apt-transport-https build-essential dirmngr libxml-parser-perl neofetch git lsof
apt-get install -y \
bzip2 gzip coreutils wget screen rsyslog iftop htop net-tools \
zip unzip curl nano sed gnupg gnupg1 bc apt-transport-https \
build-essential dirmngr libxml-parser-perl neofetch git lsof
echo "clear" >> .profile
echo "menu" >> .profile

# install webserver
apt -y install nginx
cd
rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
wget -O /etc/nginx/nginx.conf "https://raw.githubusercontent.com/vibecodingxx/trix/main/others/nginx.conf"
mkdir -p /home/vps/public_html
#wget -O /etc/nginx/conf.d/vps.conf "https://raw.githubusercontent.com/vibecodingxx/trix/main/others/vps.conf"
/etc/init.d/nginx restart

# install ssh badvpn for udp
cd
wget -O /usr/bin/badvpn "https://raw.githubusercontent.com/vibecodingxx/trix/main/ssh/badvpn-udpgw64"
chmod +x /usr/bin/badvpn
cat> /etc/systemd/system/badvpn.service << END
[Unit]
Description=BadVPN Gaming Support
Documentation=https://t.me/weloveana
After=syslog.target network-online.target

[Service]
User=root
NoNewPrivileges=true
ExecStart=/usr/bin/badvpn --listen-addr 127.0.0.1:7300 --max-clients 500
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
END
systemctl daemon-reload
systemctl enable badvpn
systemctl start badvpn
# // setting port ssh
cd
apt-get -y update
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g'

# /etc/ssh/sshd_config
sed -i '/Port 22/a Port 500' /etc/ssh/sshd_config
sed -i '/Port 22/a Port 2222' /etc/ssh/sshd_config
sed -i '/Port 22/a Port 51443' /etc/ssh/sshd_config
sed -i '/Port 22/a Port 58080' /etc/ssh/sshd_config
sed -i '/Port 22/a Port 200' /etc/ssh/sshd_config
sed -i 's/#Port 22/Port 22/g' /etc/ssh/sshd_config
/etc/init.d/ssh restart

# // install dropbear
apt install -y dropbear

# recreate configuration dropbear
cat > /etc/default/dropbear <<'EOF'
NO_START=0
DROPBEAR_PORT=143
DROPBEAR_EXTRA_ARGS="-p 109 -p 22"
DROPBEAR_BANNER=""
EOF

# make sure the shell is restricted to certain users (if necessary)
grep -qxF "/bin/false" /etc/shells || echo "/bin/false" >> /etc/shells
grep -qxF "/usr/sbin/nologin" /etc/shells || echo "/usr/sbin/nologin" >> /etc/shells

# Systemd Dropbear Service
tee /etc/systemd/system/dropbear.service > /dev/null <<'EOF'
[Unit]
Description=Lightweight SSH server
Documentation=man:dropbear(8)
After=network.target

[Service]
Environment=DROPBEAR_PORT=22 DROPBEAR_RECEIVE_WINDOW=65536
EnvironmentFile=-/etc/default/dropbear

# Clear previous ExecStart and set new one that includes banner
ExecStart=/usr/sbin/dropbear -EF -p "$DROPBEAR_PORT" -W "$DROPBEAR_RECEIVE_WINDOW" -b "$DROPBEAR_BANNER" $DROPBEAR_EXTRA_ARGS

KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# enable & restart dropbear
systemctl enable dropbear
systemctl restart dropbear

# setup old vnstat
apt -y install vnstat
/etc/init.d/vnstat restart
apt -y install libsqlite3-dev
wget https://github.com/NevermoreSSH/addons/releases/download/vnstat-2.6/vnstat-2.6.tar.gz
tar zxvf vnstat-2.6.tar.gz
cd vnstat-2.6
./configure --prefix=/usr --sysconfdir=/etc && make && make install
cd
vnstat -u -i $NET
sed -i 's/Interface "'""eth0""'"/Interface "'""$NET""'"/g' /etc/vnstat.conf
chown vnstat:vnstat /var/lib/vnstat -R
systemctl enable vnstat
/etc/init.d/vnstat restart
rm -f /root/vnstat-2.6.tar.gz
rm -rf /root/vnstat-2.6

# install stunnel
apt install stunnel4 -y
cat > /etc/stunnel/stunnel.conf <<-END
cert = /etc/stunnel/stunnel.pem
pid = /var/run/stunnel4/stunnel.pid
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear]
accept = 222
connect = 127.0.0.1:22

[dropbear2]
accept = 777
connect = 127.0.0.1:109

[wss-stunnel]
accept = 2096
connect = 127.0.0.1:2091
END

groupadd stunnel4
useradd -r -g stunnel4 -s /usr/sbin/nologin stunnel4

mkdir -p /var/run/stunnel4
chown stunnel4:stunnel4 /var/run/stunnel4

# make a certificate
openssl genrsa -out key.pem 2048
openssl req -new -x509 -key key.pem -out cert.pem -days 1095 \
-subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"
cat key.pem cert.pem >> /etc/stunnel/stunnel.pem

# conf stunnel
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
/lib/systemd/systemd-sysv-install enable stunnel4
systemctl start stunnel4
/etc/init.d/stunnel4 restart

# install lolcat
wget https://raw.githubusercontent.com/vibecodingxx/trix/main/others/lolcat.sh &&  chmod +x lolcat.sh && ./lolcat.sh

# install fail2ban
apt -y install fail2ban

# Instal DDOS Flate
if [ -d '/usr/local/ddos' ]; then
	echo; echo; echo "Please un-install the previous version first"
	exit 0
else
	mkdir /usr/local/ddos
fi
clear
echo; echo 'Installing DOS-Deflate 0.6'; echo
echo; echo -n 'Downloading source files...'
wget -q -O /usr/local/ddos/ddos.conf http://www.inetbase.com/scripts/ddos/ddos.conf
echo -n '.'
wget -q -O /usr/local/ddos/LICENSE http://www.inetbase.com/scripts/ddos/LICENSE
echo -n '.'
wget -q -O /usr/local/ddos/ignore.ip.list http://www.inetbase.com/scripts/ddos/ignore.ip.list
echo -n '.'
wget -q -O /usr/local/ddos/ddos.sh http://www.inetbase.com/scripts/ddos/ddos.sh
chmod 0755 /usr/local/ddos/ddos.sh
cp -s /usr/local/ddos/ddos.sh /usr/local/sbin/ddos
echo '...done'
echo; echo -n 'Creating cron to run script every minute.....(Default setting)'
/usr/local/ddos/ddos.sh --cron > /dev/null 2>&1
echo '.....done'
echo; echo 'Installation has completed.'
echo 'Config file is at /usr/local/ddos/ddos.conf'
echo 'Please send in your comments and/or suggestions to zaf@vsnl.com'

# banner /etc/issue.net
#wget -O /etc/issue.net "https://raw.githubusercontent.com/vibecodingxx/trix/main/others/issue.net"
cat <<EOF > /etc/issue.net
<font color="white">
<H3 style="text-align:center">
🐸 Premium VPN Server ☕</span></H3>

<H3 style="text-align:center">
⚠️ Multilogin Will be BAN ‼️</span></H3>

<H3 style="text-align:center">
👮 Please Follow the Rules </span></H3>
<font>

<H3 style="text-align:center">
👍 Thanks for the support 👍</span></H3>
<font>
EOF
echo "Banner /etc/issue.net" >>/etc/ssh/sshd_config
sed -i 's@DROPBEAR_BANNER=""@DROPBEAR_BANNER="/etc/issue.net"@g' /etc/default/dropbear

# block torrent
iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP
iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP
iptables -A FORWARD -m string --string "find_node" --algo bm -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP
iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
iptables -A FORWARD -m string --algo bm --string "torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce" -j DROP
iptables -A FORWARD -m string --algo bm --string "info_hash" -j DROP
iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload

# cron setup
echo "0 4 * * * root xp-xrayssh" >> /etc/crontab
echo "50 4 * * * root clear-log" >> /etc/crontab
echo "0 5 * * * root reboot" >> /etc/crontab
echo "0 10 * * * root notyexpired" >> /etc/crontab
echo "$((RANDOM % 60)) */6 * * * root info" | tee -a /etc/crontab
echo "$((RANDOM % 60)) 2,16 * * * root backup" | tee -a /etc/crontab

# remove unnecessary files
cd
apt autoclean -y
apt -y remove --purge unscd
apt-get -y --purge remove samba*;
apt-get -y --purge remove apache2*;
apt-get -y --purge remove bind9*;
apt-get -y remove sendmail*
apt autoremove -y

# finishing
cd
chown -R www-data:www-data /home/vps/public_html
/etc/init.d/nginx restart
/etc/init.d/openvpn restart
/etc/init.d/cron restart
/etc/init.d/ssh restart
/etc/init.d/dropbear restart
/etc/init.d/fail2ban restart
/etc/init.d/vnstat restart
/etc/init.d/stunnel4 restart
history -c
echo "unset HISTFILE" >> /etc/profile

# delete setup
cd
rm -f /root/key.pem
rm -f /root/cert.pem
rm -f /root/ssh-vpn.sh
clear
 