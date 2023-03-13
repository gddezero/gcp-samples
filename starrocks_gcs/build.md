# Build StarRocks BE
A quick guide of how to build StarRocks Ubuntu 22.04

```bash
sudo apt-get update -y
sudo apt-get install --no-install-recommends -y \
    automake binutils-dev bison byacc ccache flex libiberty-dev libtool maven zip python3 python-is-python3 make cmake gcc g++ default-jdk git patch lld bzip2 wget unzip curl vim tree net-tools openssh-client tmux libssl-dev

git clone https://github.com/gddezero/starrocks.git
```

## Build thirdparty libraries

```bash
git checkout fix-gcs-error-partitioned-table-3p
export JAVA_HOME=/lib/jvm/default-java
starrocks/thirdparty/build-thirdparty.sh
```

## Build Starrocks BE

```bash
git checkout fix-gcs-error-partitioned-table-be
starrocks/build.sh --be --clean -j 32
```

Change the parallism according to the number of CPU.
The BE binary can be found in starrocks/be/output/lib/starrocks_be.
