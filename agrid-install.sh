#! /usr/bin/bash

# Agrid is currently running on a Linux distribution
# If you are not registred, please contact us at hello@a-grid.com

#
# FUNCTIONS
#

spin() {
    local i=0
    local sp='/-\|'
    local n=${#sp}
    printf ' '
    sleep 0.1
    while [ -d /proc/$1 ]; do
        printf '\b%s' "${sp:i++%n:1}"
        sleep 0.1
    done
}

binary_install(){
    sudo apt install curl
    sudo apt install autossh
    sudo apt-get install unzip
}

docker_install(){
    sudo apt-get -y update
    sudo apt-get -y upgrade
    sudo apt install docker.io
    systemctl start docker
    systemctl enable docker
    sudo groupadd docker
    sudo usermod -aG docker $user
    sudo curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
}

agrid_server() {
    hostnamectl set-hostname agrid
    touch /etc/modprobe.d/blacklist-axp288.conf
    echo "blacklist axp288_fuel_gauge" > /etc/modprobe.d/blacklist-axp288.conf
    sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
    # https://askubuntu.com/questions/1190217/using-syslog-to-diagnose-a-crash
    if [ "$(grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub)" != 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_idle.max_cstate=1"' ]; then
        grep -v "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub > tmpfile && mv tmpfile /etc/default/grub
        echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_idle.max_cstate=1"' >> /etc/default/grub
        sudo update-grub
    fi
    sudo apt-get install nmap -y
    sudo apt-get install -y net-tools
    sudo sysctl kernel.panic=60
    sudo sysctl kernel.softlockup_panic=1
    if [ "$(grep kernel.panic /etc/sysctl.conf)" != "kernel.panic=60" ]; then
        echo "kernel.panic=60" >> /etc/sysctl.conf
    fi
    if [ "$(grep kernel.softlockup_panic /etc/sysctl.conf)" != "kernel.softlockup_panic=1" ]; then
        echo "kernel.softlockup_panic=1" >> /etc/sysctl.conf
    fi
}

fetch_config() {
    machineId=$(cat /etc/machine-id)
    url="$AGRID_API_URL/$machineId/$AGRID_API_KEY"
    echo $url
    http_code=$(curl $url -LO -w "%{http_code}")
    x=1
    if [ "$http_code" != "200" ]; then
        echo "Error while fetching files. Verify that your API key is correct."
        exit
    fi
    unzip -o $AGRID_API_KEY
    chmod +x install.sh
    /bin/bash install.sh
    rm install.sh
    rm hourly-cron.sh
    rm restart-cron.sh
    rm $AGRID_API_KEY
}

#
# REQUIRED environment variables.
#

AGRID_API_KEY=${AGRID_API_KEY:=}   # API key to authenticate against Agrid verification
AGRID_API_URL=${AGRID_API_URL:=}   # Agrid API url

[ -z "$AGRID_API_KEY" ]  && echo "Required environment variable \$AGRID_API_KEY not set." && exit
[ -z "$AGRID_API_URL" ]  && echo "Required environment variable \$AGRID_API_URL not set." && exit

#
# OPTIONAL environment variables.
#

AGRID_SERVER=${AGRID_SERVER:=}

#
# OTHER requirements
#

[[ "$OSTYPE" != "linux-gnu"* ]] && echo "Agrid must be run on Linux OS" && exit

main(){
    echo ">> Installing binaries"
    binary_install
    echo ">> Installing docker"
    docker_install
    echo ">> Fetching data"
    fetch_config & PID=$!
    spin $PID
    
    #
    # IF AGRID_SERVER variable is met, a few adjustments must be done
    #
    
    if [[ "$AGRID_SERVER" == "1"* ]]; then
        echo ">> Agrid special setup"
        agrid_server & PID=$!
        spin $PID
    fi
}

echo "
           _____ _____  _____ _____
     /\   / ____|  __ \|_   _|  __ \
    /  \ | |  __| |__) | | | | |  | |
   / /\ \| | |_ |  _  /  | | | |  | |
  / ____ \ |__| | | \ \ _| |_| |__| |
 /_/    \_\_____|_|  \_\_____|_____/
"
main
exit
