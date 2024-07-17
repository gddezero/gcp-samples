import com.databricks.spark.sql.perf.tpcds.TPCDSTables

val rootDir = "<ROOT_DIR>"
val dsdgenDir = "/opt/gcp-samples/tpcds_dataproc/tpcds-kit/tools"
val scaleFactor = "1000"
val format = "parquet"
val databaseName = "tpcds1000"
val sqlContext = spark.sqlContext

val tables = new TPCDSTables(sqlContext,
dsdgenDir = dsdgenDir, 
scaleFactor = scaleFactor,
useDoubleForDecimal = true, 
useStringForDate = true)

sql(s"create database $databaseName") 

tables.createExternalTables(rootDir, 
format, 
databaseName, 
overwrite = true, 
discoverPartitions = true)

// tables.analyzeTables(databaseName, analyzeColumns = true)
