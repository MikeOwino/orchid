#!/bin/bash
set -e
cd "$(dirname "$0")/.."

env/setup-lnx.sh

apt-get -y install software-properties-common
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xB1998361219BD9C9
apt-add-repository "deb http://repos.azul.com/azure-only/zulu/apt stable main"
apt-get -y install zulu-8-azure-jdk='*'
export JAVA_HOME=/usr/lib/jvm/zulu-8-azure-amd64

curl -o android-sdk.zip https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip
mkdir -p /usr/local/lib/android
unzip -d /usr/local/lib/android/sdk android-sdk.zip
rm -f android-sdk.zip
export ANDROID_HOME=/usr/local/lib/android/sdk

env/setup-ndk.sh

uid=$1
shift
# XXX: this is a horrible workaround for env/docker.sh due to the limited way git fixed CVE-2022-24765
if [[ ${uid} -eq 0 ]]; then
    exec "$@"
else
    apt-get -y install sudo
    chmod 755 ~
    chown -R "${uid}" ~
    exec sudo -u "#${uid}" "$@"
fi
