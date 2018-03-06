#!/bin/bash

# script to initialize RaspberryPi / Homebridge configuration/plugins

# PREREQUISITES:
# raspberian installed on sd card
# ssh enabled
#    - can be done on first boot
#        - place file with name "ssh" into the root of SD CARD
#    - once booted, run "sudo raspi-config" and enable ssh access
# connect to internet

####################################################
## OS AND DEFAULT PACKAGES INSTALLATION (FOR iOS) ##
####################################################

# update OS
echo "INFO: updating OS"
sudo apt-get update
sudo apt-get upgrade -y

# install possible needed packages
echo "INFO: installing tools"
sudo apt-get install -y git make

# install NodeJS
# for Raspberry Pi with an ARMv7 chip or better
# https://nodejs.org/en/download/package-manager/#debian-and-ubuntu-based-linux-distributions
echo "INFO: installing NodeJS"
mkdir ~/install
cd ~/install
curl -sL https://deb.nodesource.com/setup_8.x| sudo -E bash -
sudo apt-get install -y nodejs

# Install Avahi and other Dependencies
echo "INFO: installing necessary dependencies"
sudo apt-get install -y libavahi-compat-libdnssd-dev

# Install Homebridge
echo "INFO: installing Homebridge"
sudo npm install -g --unsafe-perm homebridge

# setup startup script for Homebridge (to start on boot)
sudo cat <<EOF >> /etc/default/homebridge
# Defaults / Configuration options for homebridge
# The following settings tells homebridge where to find the config.json file and where to persist the data (i.e. pairing and others)
HOMEBRIDGE_OPTS=-U /var/homebridge/.homebridge

# If you uncomment the following line, homebridge will log more
# You can display this via systemd's journalctl: journalctl -f -u homebridge
# DEBUG=*

EOF

sudo cat <<EOF >> /etc/systemd/system/homebridge.service
[Unit]
Description=Node.js HomeKit Server
After=syslog.target network-online.target

[Service]
Type=simple
User=pi
EnvironmentFile=/etc/default/homebridge
ExecStart=/usr/bin/homebridge $HOMEBRIDGE_OPTS
Restart=on-failure
RestartSec=10
KillMode=process

[Install]
WantedBy=multi-user.target

EOF

echo "INFO: creating homebridge directories"
sudo mkdir /var/homebridge
mkdir ~/.homebridge
sudo ln -s ~/.homebridge /var/homebridge
sudo systemctl daemon-reload
sudo systemctl enable homebridge

echo "INFO: status of hombridge service is: "
sudo systemctl status homebridge

echo "INFO: start dependencies"
sudo /etc/init.d/dbus start
sudo /etc/init.d/avahi-daemon start

echo "INFO: Installing mDNS service"
sudo npm install -g --unsafe-perm mdns
cd /usr/lib/node_modules/homebridge/
sudo npm rebuild --unsafe-perm

# pigpiod startup scripts
# https://github.com/joan2937/pigpio/tree/master/util
echo "INFO: creating pigpiod startup scripts"
sudo cat <<EOF >> /etc/init.d/pigpiod
#!/bin/sh
### BEGIN INIT INFO
# Provides:             pigpiod
# Required-Start:
# Required-Stop:
# Default-Start:        2 3 4 5
# Default-Stop:         0 1 6
# Short-Description:    pigpio daemon
# Description:          pigpio daemon required to control GPIO pins via pigpio \$
### END INIT INFO

# Actions
case "\$1" in
  start)
    pigpiod
    ;;
  stop)
    pkill pigpiod
    ;;
  restart)
    pkill pigpiod
    pigpiod
    ;;
  *)
    echo "Usage: \$0 start" >&2
    exit 3
    ;;
esac

exit 0

EOF
sudo chmod +x /etc/init.d/pigpiod
sudo update-rc.d pigpiod defaults
sudo update-rc.d pigpiod enable
echo "INFO: starting pigpiod service"
sudo service pigpiod start

# monitoring Homebridge from browser
echo "INFO: installing package to monitor Homebridge from web browser http://<raspberrypi IP>:8080  admin/admin"
sudo npm i -g homebridge-config-ui

###########################################
## HOMEBRIDGE (NPM) PLUGINS INSTALLATION ##
###########################################

# DHT22 temperature and humidity sensors support
# http://www.instructables.com/id/RPIHomeBridge-TemperatureHumidity-Sensor/
echo "INFO: installing Homebridge plugin to support DHT22 sensors"
sudo npm install -g homebridge-dht

echo "INFO: installing pigpiod libraries (if not yet present)"
sudo apt-get install -y pigpio python-pigpio python3-pigpio

echo "INFO: Download the DHT22 Sample program from herehttp://abyz.co.uk/rpi/pigpio/code/DHTXXD.zip"
cd ~/.homebridge
mkdir DHTXXD
cd DHTXXD
wget http://abyz.co.uk/rpi/pigpio/code/DHTXXD.zip
unzip DHTXXD.zip
cp /usr/lib/node_modules/homebridge-dht/test_DHTXXD.patch .
patch < ./test_DHTXXD.patch
gcc -Wall -pthread -o DHTXXD test_DHTXXD.c DHTXXD.c -lpigpiod_if2
sudo cp DHTXXD /usr/local/bin/dht22
sudo chmod a+x /usr/local/bin/dht22
echo "INFO: testing dht22 script:"
dht22

echo "INFO: creating cputemp script to monitor CPU temperature"
sudo cat <<EOF >> /usr/local/bin/cputemp
#!/bin/sh
cpuTemp0=\$(cat /sys/class/thermal/thermal_zone0/temp)
cpuTemp1=\$((\$cpuTemp0/1000))
cpuTemp2=\$((\$cpuTemp0/100))
cpuTempM=\$((\$cpuTemp2 % \$cpuTemp1))
echo \$cpuTemp1" C"

EOF
sudo chmod +x /usr/local/bin/cputemp
echo "INFO: testing cputemp script:"
cputemp

# WEATHER PLUGIN
# https://www.npmjs.com/package/homebridge-weather
echo "INFO: installing Weather Homebridge plugin"
sudo npm install -g homebridge-weather












