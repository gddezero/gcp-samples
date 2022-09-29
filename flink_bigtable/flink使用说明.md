# flink使用说明，仅用于macbook

## 使用前提
1. 需要安装java 8 以上版本，最好是11


## 重新编译 flink-sql-connector-hbase-2.2_2.11-1.14.5.jar

1. 下载 flink-release-1.14.5 
2. 进入 flink-connectors/flink-sql-connector-hbase-2.2
3. 修改pom.xml, 找到以下内容并注释掉：

```
<relocation>
  <pattern>org.apache.hadoop.hbase</pattern>
  <shadedPattern>org.apache.flink.hbase.shaded.org.apache.hadoop.hbase</shadedPattern>
  <!-- HBase client uses shaded KeyValueCodec to encode data and put the class name in
       The header of request, the HBase region server can not load the shaded
       KeyValueCodec class when decode the data, so we exclude them here. -->
  <excludes>
     <exclude>org.apache.hadoop.hbase.codec.*</exclude>
  </excludes>
</relocation>
```

4. 运行mvn package
5. 将结果替换到lib/

## 环境配置
1. 解压文件即可
2. 进入flink目录，
   * lib为flink所使用的jar
   * depend为bigtabl-hbase不同的版本的jar包
   * conf/hbase-default.xml为hbase和bigtable的配置

## 启动本地集群
```
bash bin/start-cluster.sh
```

测试： 访问localhost:8081


## BigTable准备

Bigtable里的表`rates`需要存在，并且改表需要有两个column families: 
- currency
- f


## 启动flink sql
```
export HBASE_CONF_DIR=`pwd`/conf

bin/sql-client.sh -l lib embedded

```

sql执行的语句：  
创建  
```
CREATE TABLE rates (
    currency STRING,
    f ROW<rate DECIMAL(32, 2)>
) WITH (
 'connector' = 'hbase-2.2',
 'table-name' = 'rates',
 'zookeeper.quorum' = 'localhost:2181'
);
```

插入数据  
```
INSERT INTO rates 
    VALUES 
        ('USD', ROW(6.45)),
        ('JPY', ROW(0.06)),
        ('EUR', ROW(7.91)),
        ('GBP', ROW(8.78));
```

提交之后，能通过localhost:8081中**jobs/completed jobs**看到任务运行结果

现在存在的异常信息
具体异常情况在error.log中
* 注意：flink的日志等级为DEBUG，但flink日志中出现折叠情况，因为bigtable到hbase的sdk问题

