from pyspark.sql import SparkSession, functions as F


spark = SparkSession.builder.appName("ksenia-hw4").enableHiveSupport().getOrCreate()

orders = spark.read.option("header", True).csv(
    "hdfs:///user/dpe_ksenia/hw4/input/orders.csv"
)
monthly = (
    orders.withColumn("amount", F.col("amount").cast("double"))
    .withColumn("order_month", F.date_format(F.to_date("order_date"), "yyyy-MM"))
    .filter(F.col("amount").isNotNull() & F.col("order_month").isNotNull())
    .groupBy("city", "order_month")
    .agg(
        F.count("order_id").alias("orders"),
        F.round(F.sum("amount"), 2).alias("total_amount"),
    )
)

spark.sql("CREATE DATABASE IF NOT EXISTS ksenia_hw4")
monthly.write.format("hive").mode("overwrite").partitionBy("order_month").saveAsTable(
    "ksenia_hw4.orders_by_city"
)
spark.sql("SELECT * FROM ksenia_hw4.orders_by_city").show()
spark.stop()
