#!/bin/bash

cd /opt
git clone https://github.com/gddezero/gcp-samples.git
cd tpcds_dataproc
tar -zxvf tpcds-kit.tar.gz
DW_BUCKET=$(/usr/share/google/get_metadata_value attributes/DW_BUCKET)
sed -i "s/DW_BUCKET/${DW_BUCKET}/g" datagen.scala