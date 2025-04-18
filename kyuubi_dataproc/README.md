# Initialization script for intstalling Kyuubi on Dataproc

This is a initialization script for intstalling Kyuubi on Dataproc. Follow the steps to deploy a dataproc cluster with Kyuubi installed.

1. Upload `init_kyuubi.sh` to the GCS bucket
2. Deploy dataproc cluster with the following parameters:

```bash
  --properties "core:hadoop.proxyuser.root.hosts=*" \
  --properties "core:hadoop.proxyuser.root.groups=*" \
  --properties "core:hadoop.proxyuser.root.users=*" \
  --properties "hive:hive.server2.enable.doAs=true" \
  --metadata KYUUBI_VERSION=1.10.1 \
  --initialization-actions 'gs://<gcs bucket and path>/init_kyuubi.sh' \
```

You can specify the Kyuubi version in the metadata parameter, for example:

```bash
--metadata KYUUBI_VERSION=1.10.1 \
```

3. Once the Dataproc cluster is deployed, login to the master with SSH and test kyuubi with

```bash
HOST_MASTER=$(/usr/share/google/get_metadata_value attributes/dataproc-master)
KYUUBI_VERION=$(/usr/share/google/get_metadata_value attributes/KYUUBI_VERSION)

/oss/kyuubi/apache-kyuubi-${KYUUBI_VERION}-bin/bin/beeline -u "jdbc:hive2://${HOST_MASTER}:10009/" -n hive -e "select 1;"
```