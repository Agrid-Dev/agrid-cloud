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
    sudo apt install -y docker.io
    systemctl start docker
    systemctl enable docker
    sudo groupadd docker
    sudo usermod -aG docker $user
    sudo curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
}

agrid_server() {
    hostnamectl set-hostname agrid
    sudo apt-get install nmap -y
    sudo apt-get install -y net-tools
}

fetch_config() {
    MACHINE_ID=$(cat /etc/machine-id)
    url="$AGRID_API_URL/$MACHINE_ID/$AGRID_API_KEY"
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
    cd /tmp
    echo ">> Installing binaries"
    binary_install
    echo ">> Installing docker"
    docker_install
    
    #
    # IF AGRID_SERVER variable is met, a few adjustments must be done
    #
    
    if [[ "$AGRID_SERVER" == "1"* ]]; then
        echo ">> Agrid special setup"
        agrid_server & PID=$!
        spin $PID
    fi
    
    echo ">> Fetching data"
    fetch_config & PID=$!
    spin $PID
}

echo "
                     _     _ 
     /\             (_)   | |
    /  \   __ _ _ __ _  __| |
   / /\ \ / _` | '__| |/ _` |
  / ____ \ (_| | |  | | (_| |
 /_/    \_\__, |_|  |_|\__,_|
           __/ |             
          |___/              
          
"
main
exit


