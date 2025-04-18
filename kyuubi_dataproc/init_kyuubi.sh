#!/bin/bash
export BASE_DIR=/opt/kyuubi
export KYUUBI_VER=$(/usr/share/google/get_metadata_value attributes/KYUUBI_VERSION)
export ROLE=$(/usr/share/google/get_metadata_value attributes/dataproc-role)


install_kyuubi() {
    mkdir ${BASE_DIR}
    wget https://dlcdn.apache.org/kyuubi/kyuubi-${KYUUBI_VER}/apache-kyuubi-${KYUUBI_VER}-bin.tgz -P /tmp
    tar xzvf /tmp/apache-kyuubi-${KYUUBI_VER}-bin.tgz -C ${BASE_DIR}/
    cd ${BASE_DIR}/apache-kyuubi-${KYUUBI_VER}-bin
    cp conf/kyuubi-defaults.conf.template conf/kyuubi-defaults.conf
    
    echo "Start Kyuubi server"
    bin/kyuubi start

    # echo "Test Kyuubi connection"
    # bin/beeline -u "jdbc:hive2://${HOST_MASTER}:10009/" -n hive -e "select 1;"
    # bin/kyuubi-ctl delete engine --user hive

}


if [[ "${ROLE}" == 'Master' ]]; then
    echo "Installing Kyuubi"
    install_kyuubi
    echo "Kyuubi installed"
fi