This doc describes how to build Flink Google Storage plugin on Flink 1.11 to support streaming writes to Google Storage

# Install sdkman on MacOS

```bash
curl -s "https://get.sdkman.io" | bash
```

Execute after installation:

```bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
```

# Install JDK 8 and maven 3.2 on MacOS

```bash
sdk install maven 3.2.5
sdk install java 8.0.352-tem
```

# Fork the Flink git into your own repo
Visit [Flink](https://github.com/apache/flink) and fork into your own repo

# Clone to local and create new branch based on 1.11.0

```bash
git clone https://github.com/gddezero/flink.git
git checkout release-1.11
git checkout -b flink-1.11-gs release-1.11
```

# Cherry pick the commit for gcs

```bash
git checkout release-1.15
cd flink-filesystems/flink-gs-fs-hadoop
git log --skip 2 --pretty=format:"%h" .
```

Get the latest commmit ids:
0e4a6661dee 1a6e3387fdf 19eb5f3e5d0 fb634aa050f ea1fb87d269 54b21e87a59


Run cherry pick to get all the changes into 1.11
```bash
git checkout flink-1.11-gs
git fetch
git cherry-pick 0e4a6661dee 1a6e3387fdf 19eb5f3e5d0 fb634aa050f ea1fb87d269 54b21e87a59
```
There are conflicts need to resolve:

Auto-merging flink-core/src/main/java/org/apache/flink/core/fs/FileSystem.java
CONFLICT (content): Merge conflict in flink-core/src/main/java/org/apache/flink/core/fs/FileSystem.java
Auto-merging flink-filesystems/flink-hadoop-fs/src/main/java/org/apache/flink/runtime/fs/hdfs/HadoopFileSystem.java
Auto-merging flink-filesystems/pom.xml
error: could not apply 0e4a6661dee... [FLINK-11838][fs][gs] Create Google Storage file system with RecoverableWriter support

- flink-core/src/main/java/org/apache/flink/core/fs/FileSystem.java
Open any IDE and open the source file. Merge the 2 lines so that the final result looks like:
```java 
 .put("gs", "flink-gs-fs-hadoop")
 .put("swift", "flink-swift-fs-hadoop")
```

Continue the cherry pick:
```bash
git add flink-core/src/main/java/org/apache/flink/core/fs/FileSystem.java
git cherry-pick --continue
```

Remove these test java classes because they introduce too many dependencies and changes:
```bash
git rm flink-filesystems/flink-gs-fs-hadoop/src/test/java/org/apache/flink/fs/gs/utils/ConfigUtilsHadoopTest.java
git rm flink-filesystems/flink-gs-fs-hadoop/src/test/java/org/apache/flink/fs/gs/utils/ConfigUtilsStorageTest.java
git rm flink-filesystems/flink-gs-fs-hadoop/src/test/java/org/apache/flink/fs/gs/GSFileSystemScenarioTest.java
git rm flink-filesystems/flink-gs-fs-hadoop/src/test/java/org/apache/flink/fs/gs/writer/GSRecoverableFsDataOutputStreamTest.java
```

Add the changed file:
```bash
git add -A
```

# Build Flink
Go to the root dir of Flink source code. Execute:

```bash
mvn clean install -DskipTests -Dscala-2.12 -Dfast -T 1C

# Copy the binary to tgz
cd /Users/maxwellx/Documents/code/flink/build-target
tar -czvf /Users/maxwellx/Documents/flink/flink-1.11.0-gs-bin-scala_2.12.tgz .
cd /Users/maxwellx/Documents/flink
mkdir flink-1.11.0-gs-bin-scala_2.12
tar -zxvf flink-1.11.0-gs-bin-scala_2.12.tgz -C flink-1.11.0-gs-bin-scala_2.12


```

