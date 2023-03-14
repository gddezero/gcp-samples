#!/bin/bash
apt install wget tmux -y
cd /opt
git clone https://github.com/gddezero/gcp-samples.git
cd gcp-samples/tpcds_dataproc
tar -zxvf tpcds-kit.tar.gz
DW_BUCKET=$(/usr/share/google/get_metadata_value attributes/DW_BUCKET)
sed -i "s/DW_BUCKET/${DW_BUCKET}/g" datagen.scala