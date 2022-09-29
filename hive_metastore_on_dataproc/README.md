# Deploy 3 master Dataproc cluster for metastore

## Environment variables

```shell
export PROJECT=forrest-test-project-333203
export PROJECT_NUMBER=49133816376
export REGION=us-central1
export ZONE=us-central1-f
export NETWORK=bigdata-network
export SUBNET=dataflow-network
export METASTORE_DB=hive
export SQL_INSTANCE=mysql-test
export HIVE_PASSWORD_GS=gs://forrest-bigdata-bucket/cloudsql_hive_encrypted/hive-password.encrypted
export WAREHOUSE_BUCKET=gs://my-dw-bucket/hive
export DATAPROC_BUCKET=forrest-dataproc-bucket
export CLUSTER_NAME=hive-phs-cluster
export CLUSTER_ZONE=us-central1-f
export SA=notebook@forrest-test-project-333203.iam.gserviceaccount.com
```

## Deploy Dataproc cluster

```shell
gcloud dataproc clusters create ${CLUSTER_NAME} \
--project $PROJECT \
--scopes cloud-platform \
--region ${REGION} \
--zone ${ZONE} \
--metadata "hive-metastore-instance=${PROJECT}:${REGION}:${SQL_INSTANCE}" \
--metadata "kms-key-uri=projects/${PROJECT}/locations/global/keyRings/my-key-ring/cryptoKeys/my-key" \
--metadata "db-hive-password-uri=${HIVE_PASSWORD_GS}" \
--metadata "use-cloud-sql-private-ip=true" \
--metadata "hive-metastore-db=${METASTORE_DB}" \
--enable-component-gateway \
--no-address \
--subnet ${SUBNET} \
--initialization-actions "gs://goog-dataproc-initialization-actions-${REGION}/cloud-sql-proxy/cloud-sql-proxy.sh" \
--bucket ${DATAPROC_BUCKET} \
--temp-bucket ${DATAPROC_BUCKET} \
--service-account ${SA} \
--num-masters 3 \
--num-workers 2 \
--master-machine-type n2d-standard-4 \
--master-min-cpu-platform "AMD Milan" \
--master-boot-disk-size 100 \
--master-boot-disk-type pd-ssd \
--worker-boot-disk-size 100 \
--worker-machine-type n2d-standard-2 \
--worker-min-cpu-platform  "AMD Milan"\
--image-version 2.0-debian10 \
--properties hive:hive.metastore.warehouse.dir=${WAREHOUSE_BUCKET} \
--properties "spark:spark.history.fs.logDirectory=gs://${DATAPROC_BUCKET}/phs/*/spark-job-history,mapred:mapreduce.jobhistory.read-only.dir-pattern=gs://${DATAPROC_BUCKET}/phs/*/mapreduce-job-history/done"
```

After the cluster is deployed, write down the host name of 3 master nodes:
- `${CLUSTER_NAME}-m-0.${ZONE}.c.${PROJECT}.internal`
- `${CLUSTER_NAME}-m-1.${ZONE}.c.${PROJECT}.internal`
- `${CLUSTER_NAME}-m-2.${ZONE}.c.${PROJECT}.internal`

Hive, Spark, Presto/Trino can connect to Hive metastore using thrift endpoint of 3 master nodes

## Deploy other Dataproc cluster for running jobs
Make sure to include the property:
```shell
--properties hive:hive.metastore.uris=thrift://${CLUSTER_NAME}-m-0.${ZONE}.c.${PROJECT}.internal:9083,thrift://${CLUSTER_NAME}-m-1.${ZONE}.c.${PROJECT}.internal:9083,thrift://${CLUSTER_NAME}-m-2.${ZONE}.c.${PROJECT}.internal:9083
```

## Hive with beeline
Use beeline to connect to hiveserver2:
```shell
beeline -u "jdbc:hive2://${CLUSTER_NAME}-m-0.${ZONE}.c.${PROJECT}.internal:2181,${CLUSTER_NAME}-m-1.${ZONE}.c.${PROJECT}.internal:2181,${CLUSTER_NAME}-m-2.${ZONE}.c.${PROJECT}.internal:2181/;serviceDiscoveryMode=zooKeeper;zooKeeperNamespace=hiveserver2"
```

## Presto/Trino
Set the property in configuration properties:
```
hive.metastore.uri=thrift://${CLUSTER_NAME}-m-0.${ZONE}.c.${PROJECT}.internal:9083,thrift://${CLUSTER_NAME}-m-1.${ZONE}.c.${PROJECT}.internal:9083,thrift://${CLUSTER_NAME}-m-2.${ZONE}.c.${PROJECT}.internal:9083
```

## Spark
If the Spark job is run on dataproc cluster, and the property hive:hive.metastore.uris is already set to thrift endpoints of 3 master nodes, you do not need to change anything when submitting jobs.

If you run Spark from Dataproc on GKE, make sure the dataproc cluster is created with properties:
```shell
# For Spark 3.x
--properties=^#^spark:spark.sql.catalogImplementation=hive#spark:spark.hive.metastore.uris=thrift://${CLUSTER_NAME}-m-0.${ZONE}.c.${PROJECT}.internal:9083,thrift://${CLUSTER_NAME}-m-1.${ZONE}.c.${PROJECT}.internal:9083,thrift://${CLUSTER_NAME}-m-2.${ZONE}.c.${PROJECT}.internal:9083#spark:spark.hive.metastore.warehouse.dir=<WAREHOUSE_DIR>

# For Spark 2.4 
--properties=^#^spark:spark.hadoop.sql.catalogImplementation=hive#spark:spark.hadoop.hive.metastore.uris=thrift://${CLUSTER_NAME}-m-0.${ZONE}.c.${PROJECT}.internal:9083,thrift://${CLUSTER_NAME}-m-1.${ZONE}.c.${PROJECT}.internal:9083,thrift://${CLUSTER_NAME}-m-2.${ZONE}.c.${PROJECT}.internal:9083#spark:spark.hadoop.hive.metastore.warehouse.dir=<WAREHOUSE_DIR>"
```
