# Dataproc on GKE Quickstart

## Environment variables
### Env variables for Google Cloud

**Change the values of variables to fit in your environment**

```shell
export PROJECT=forrest-test-project-333203
export PROJECT_NUMBER=49133816376
export REGION=us-central1
export ZONE=us-central1-f
export NETWORK=bigdata-network
export SUBNET=dataflow-network
export WAREHOUSE_BUCKET=gs://my-dw-bucket/hive
export DATAPROC_BUCKET=forrest-dataproc-bucket
export GKE_CLUSTER_NAME=dpgke-cluster
export GKE_MASTER_CIDR=192.168.5.0/28
export GKE_POD_CIDR=10.0.0.0/16
export GKE_SERVICE_CIDR=10.1.0.0/16
export GSA_NAME=dataproc-user
export DP_GSA="${GSA_NAME}@${PROJECT}.iam.gserviceaccount.com"
```

### Env variables for Spark history server and Hive metastore server
```shell
export PHS_CLUSTER_NAME=hive-phs-cluster
export PHS_CLUSTER_ZONE=us-central1-f
```

### Env variables for Hive metastore server
```shell
export HM_CLUSTER_NAME=hive-phs-cluster
export HM_CLUSTER_ZONE=us-central1-f
```

### Env varialbes for GKE node pools
```shell
export DP_CTRL_POOLNAME=dp-controller
export DP_CTRL_MACHINE=e2-medium
export DP_DRIVER_POOLNAME=dp-driver
export DP_DRIVER_MACHINE=n2d-standard-2
export DP_DRIVER_CPU_PLATFORM="AMD Milan"
export DP_STD_EXEC_POOLNAME=dp-exec-standard
export DP_STD_EXEC_MACHINE=n2d-standard-2
export DP_STD_EXEC_CPU_PLATFORM="AMD Milan"
export DP_STD_NAMESPACE=spark31-standard
export DP_STD_CLUSTER_NAME=gke-spark31-standard
gcloud config set project ${PROJECT}
```

## Deply Spark Persistent History Server on Dataproc
```shell
gcloud dataproc clusters create ${PHS_CLUSTER_NAME} \
--project $PROJECT \
--single-node \
--scopes cloud-platform \
--region ${REGION} \
--zone ${ZONE} \
--enable-component-gateway \
--no-address \
--subnet ${SUBNET} \
--bucket ${DATAPROC_BUCKET} \
--temp-bucket ${DATAPROC_BUCKET} \
--service-account ${DP_GSA} \
--master-machine-type n2d-standard-2 \
--master-min-cpu-platform "AMD Milan" \
--master-boot-disk-size 100 \
--master-boot-disk-type pd-ssd \
--image-version 2.0-debian10 \
--properties "spark:spark.history.fs.logDirectory=gs://${DATAPROC_BUCKET}/phs/*/spark-job-history,mapred:mapreduce.jobhistory.read-only.dir-pattern=gs://${DATAPROC_BUCKET}/phs/*/mapreduce-job-history/done"
```

## Deploy GKE cluster
```shell
gcloud container clusters create ${GKE_CLUSTER_NAME} \
--project "${PROJECT}" \
--region "${REGION}" \
--autoscaling-profile balanced \
--workload-pool "${PROJECT}.svc.id.goog" \
--enable-autoscaling \
--no-enable-autorepair \
--no-enable-basic-auth \
--enable-private-nodes \
--enable-ip-alias \
--disable-default-snat \
--metadata disable-legacy-endpoints=true \
--logging SYSTEM,WORKLOAD \
--no-enable-master-authorized-networks \
--addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver,NodeLocalDNS \
--scopes cloud-platform \
--tags dataproc,spark \
--network ${NETWORK} \
--subnetwork ${SUBNET} \
--master-ipv4-cidr ${GKE_MASTER_CIDR} \
--cluster-ipv4-cidr ${GKE_POD_CIDR} \
--services-ipv4-cidr ${GKE_SERVICE_CIDR} \
--default-max-pods-per-node 16 \
--node-locations ${ZONE} \
--machine-type e2-medium \
--disk-type=pd-standard \
--num-nodes 2 \
--min-nodes 1 \
--max-nodes 3 \
--enable-dataplane-v2
```

## Create IAM service account for agent, driver and executor
```shell
gcloud iam service-accounts create "${GSA_NAME}" \
--description "Used by Dataproc agent, driver and executor on GKE workloads."
```

## Bind roles/dataproc.worker to GSA
```shell
gcloud projects add-iam-policy-binding "${PROJECT}" \
--role roles/dataproc.worker \
--member "serviceAccount:${DP_GSA}"
```

## [Optional] Bind additional roles to GSA if spark need to access gcp services like BigQuery
```shell
gcloud projects add-iam-policy-binding "${PROJECT}" \
--role roles/bigquery.dataEditor \
--member "serviceAccount:${DP_GSA}"
```

## Bind k8s service account to IAM service account
```shell
gcloud iam service-accounts add-iam-policy-binding \
--role=roles/iam.workloadIdentityUser \
--member="serviceAccount:${PROJECT}.svc.id.goog[${DP_STD_NAMESPACE}/agent]" \
"${DP_GSA}"

gcloud iam service-accounts add-iam-policy-binding \
--role=roles/iam.workloadIdentityUser \
--member="serviceAccount:${PROJECT}.svc.id.goog[${DP_STD_NAMESPACE}/spark-driver]" \
"${DP_GSA}"

gcloud iam service-accounts add-iam-policy-binding \
--role=roles/iam.workloadIdentityUser \
--member="serviceAccount:${PROJECT}.svc.id.goog[${DP_STD_NAMESPACE}/spark-executor]" \
"${DP_GSA}"
```

## Create dataproc on GKE cluster
```shell
gcloud dataproc clusters gke create ${DP_STD_CLUSTER_NAME} \
--project=${PROJECT} \
--region=${REGION} \
--gke-cluster=${GKE_CLUSTER_NAME} \
--gke-cluster-location=${REGION} \
--spark-engine-version=3.1 \
--namespace=${DP_STD_NAMESPACE} \
--staging-bucket=${DATAPROC_BUCKET} \
--setup-workload-identity \
--history-server-cluster=${PHS_CLUSTER_NAME} \
--pools="name=${DP_CTRL_POOLNAME},roles=default,min=1,max=3,machineType=${DP_CTRL_MACHINE},locations=${ZONE}" \
--pools="name=${DP_DRIVER_POOLNAME},roles=spark-driver,min=1,max=5,machineType=${DP_DRIVER_MACHINE},locations=${ZONE},minCpuPlatform=${DP_DRIVER_CPU_PLATFORM},preemptible=false" \
--pools="name=${DP_STD_EXEC_POOLNAME},roles=spark-executor,min=1,max=5,machineType=${DP_STD_EXEC_MACHINE},locations=${ZONE},minCpuPlatform=${DP_STD_EXEC_CPU_PLATFORM},preemptible=true,localSsdCount=1" \
--properties="spark:spark.kubernetes.executor.volumes.hostPath.spark-local-dir-1.mount.path=/var/data/spark-1" \
--properties="spark:spark.kubernetes.executor.volumes.hostPath.spark-local-dir-1.options.path=/mnt/disks/ssd0" \
--properties="spark:spark.kubernetes.allocation.batch.size=1000" \
--properties="spark:spark.kubernetes.driver.annotation.prometheus.io/scrape=true" \
--properties="spark:spark.kubernetes.driver.annotation.prometheus.io/path=/metrics/executors/prometheus/" \
--properties="spark:spark.kubernetes.driver.annotation.prometheus.io/port=4040" \
--properties="spark:spark.kubernetes.driver.service.annotation.prometheus.io/scrape=true" \
--properties="spark:spark.kubernetes.driver.service.annotation.prometheus.io/path=/metrics/prometheus/" \
--properties="spark:spark.kubernetes.driver.service.annotation.prometheus.io/port=4040" \
--properties="spark:spark.ui.prometheus.enabled=true" \
--properties="spark:spark.sql.streaming.metricsEnabled=true" \
--properties="spark:spark.driver.cores=1" \
--properties="spark:spark.driver.memory=3G" \
--properties="spark:spark.driver.maxResultSize=2g" \
--properties="spark:spark.executor.cores=1" \
--properties="spark:spark.executor.memory=3G" \
--properties="spark:spark.executor.processTreeMetrics.enabled=true" \
--properties="spark:spark.checkpoint.compress=true" \
--properties="spark:spark.metrics.appStatusSource.enabled=true" \
--properties="spark:spark.eventLog.compress=true" \
--properties="spark:spark.eventLog.compression.codec=zstd" \
--properties="spark:spark.eventLog.rolling.enabled=true" \
--properties="spark:spark.eventLog.rolling.maxFileSize=10m" \
--properties="spark:spark.eventLog.logStageExecutorMetrics=true" \
--properties="spark:spark.sql.cbo.joinReorder.enabled=true" \
--properties="spark:spark.sql.statistics.histogram.enabled=true" \
--properties="spark:spark.sql.statistics.fallBackToHdfs=true" \
--properties="spark:spark.sql.catalogImplementation=hive" \
--properties="spark:spark.sql.adaptive.enabled=true" \
--properties="spark:spark.sql.adaptive.localShuffleReader.enabled=true" \
--properties="spark:spark.sql.adaptive.coalescePartitions.enabled=true" \
--properties="spark:spark.sql.adaptive.skewJoin.enabled=true" \
--properties="spark:spark.sql.autoBroadcastJoinThreshold=200M" \
--properties="spark:spark.dynamicAllocation.enabled=true" \
--properties="spark:spark.dynamicAllocation.shuffleTracking.enabled=true" \
--properties="spark:spark.dynamicAllocation.shuffleTracking.timeout=30min" \
--properties="spark:spark.dynamicAllocation.cachedExecutorIdleTimeout=30min" \
--properties="spark:spark.dynamicAllocation.executorIdleTimeout=60s" \
--properties="spark:spark.dynamicAllocation.schedulerBacklogTimeout=1s" \
--properties="spark:spark.dynamicAllocation.sustainedSchedulerBacklogTimeout=1s" \
--properties="spark:spark.speculation.interval=1s" \
--properties="spark:spark.speculation.multiplier=4.0" \
--properties="spark:spark.speculation.quantile=0.9" \
--properties="spark:spark.speculation.task.duration.threshold=30s" \
--properties="spark:spark.hive.metastore.uris=thrift://${HM_CLUSTER_NAME}-m.${HM_CLUSTER_ZONE}.c.${PROJECT}.internal:9083" \
--properties="spark:spark.hive.metastore.warehouse.dir=${WAREHOUSE_BUCKET}" \
--properties="spark:spark.metrics.conf.*.sink.prometheusServlet.class=org.apache.spark.metrics.sink.PrometheusServlet" \
--properties="spark:spark.metrics.conf.*.sink.prometheusServlet.path=/metrics/prometheus" \
--properties="spark:spark.metrics.conf.master.sink.prometheusServlet.path=/metrics/master/prometheus" \
--properties="spark:spark.metrics.conf.applications.sink.prometheusServlet.path=/metrics/applications/prometheus" \
--properties="dataproc:dataproc.gke.agent.google-service-account=${DP_GSA}" \
--properties="dataproc:dataproc.gke.spark.driver.google-service-account=${DP_GSA}" \
--properties="dataproc:dataproc.gke.spark.executor.google-service-account=${DP_GSA}"
```

## Submit job - Spark Pi
```shell
gcloud dataproc jobs submit spark \
--project=${PROJECT} \
--region=${REGION} \
--cluster=${DP_STD_CLUSTER_NAME} \
--properties="spark.app.name=SparkPi,spark.dynamicAllocation.maxExecutors=5" \
--class=org.apache.spark.examples.SparkPi \
--jars=local:///usr/lib/spark/examples/jars/spark-examples.jar \
-- 10000
```

You can open Spark History Server UI to check the status of the job
- Go to Dataproc UI
- Click the PHS cluster
- Go to WEB INTERFACES and click 'Spark History Server'

You can observe auto scaling of the executor node pool of GKE cluster. It will scale out during the job run and scale in after the job is completed. Feel free to run other Spark, pySpark and Spark SQL jobs on this cluster.

## Clean up the environment
### Delete dataproc clusters
```shell
gcloud dataproc clusters delete ${DP_STD_CLUSTER_NAME} \
--project=${PROJECT} \
--region=${REGION}
```

```shell
gcloud dataproc clusters delete ${PHS_CLUSTER_NAME} \
--project=${PROJECT} \
--region=${REGION}
```

### Delete GKE cluster
**If you want to keep the cluster and delete the node pools, then skip this step**
```shell
gcloud container clusters delete ${GKE_CLUSTER_NAME} \
--project "${PROJECT}" \
--region "${REGION}"
```

### Delete GKE node pools
```shell
gcloud container node-pools delete ${DP_CTRL_POOLNAME} \
--cluster=${GKE_CLUSTER_NAME} \
--project=${PROJECT} \
--region=${REGION}

gcloud container node-pools delete ${DP_DRIVER_POOLNAME} \
--cluster=${GKE_CLUSTER_NAME} \
--project=${PROJECT} \
--region=${REGION}

gcloud container node-pools delete ${DP_STD_EXEC_POOLNAME} \
--cluster=${GKE_CLUSTER_NAME} \
--project=${PROJECT} \
--region=${REGION}
```