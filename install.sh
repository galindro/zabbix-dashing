#!/bin/bash

INSTALL_DIR=`pwd`

fn_error() {
  echo "NOK!!"
  exit 1
}

apt-get install -y ruby ruby-dev nodejs g++ bundler || fn_error
gem install -V dashing || fn_error
bundle || fn_error
ln -sf ${INSTALL_DIR}/zabbix-dashing.init /etc/init.d/zabbix-dashing || fn_error
ln -sf ${INSTALL_DIR}/zabbix-dashing-init.conf /etc/default/ || fn_error
update-rc.d zabbix-dashing defaults || fn_error
echo "Zabbix dashing installed successfully. Start service with /etc/init.d/zabbix-dashing start"
exit 0
