import com.databricks.spark.sql.perf.tpcds.TPCDS

val sqlContext = spark.sqlContext
val tpcds = new TPCDS (sqlContext = sqlContext)
// Set:
val databaseName = "tpcds1000" // name of database with TPCDS data.
val resultLocation = "/results" // place to write results
val iterations = 1 // how many iterations of queries to run.
val queries = tpcds.tpcds2_4Queries // queries to run.
val timeout = 24*60*60 // timeout, in seconds.
// Run:
sql(s"use $databaseName")
val experiment = tpcds.runExperiment(
  queries, 
  iterations = iterations,
  resultLocation = resultLocation,
  forkThread = true)
experiment.waitForFinish(timeout)