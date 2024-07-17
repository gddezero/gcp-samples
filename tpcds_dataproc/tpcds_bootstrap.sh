#!/bin/bash
apt install wget tmux -y
cd /opt
git clone https://github.com/gddezero/gcp-samples.git
cd gcp-samples/tpcds_dataproc
tar -zxvf tpcds-kit.tar.gz
ROOT_DIR=$(/usr/share/google/get_metadata_value attributes/ROOT_DIR)
sed -i "s/ROOT_DIR/${ROOT_DIR}/g" datagen.scala
sed -i "s/ROOT_DIR/${ROOT_DIR}/g" create_table.scala