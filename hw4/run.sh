#!/usr/bin/env bash
set -euo pipefail

BASE=/srv/dpe/ksenia
ROOT=$BASE/homeworks
[[ $(id -un) == dpe_ksenia && $(hostname -s) == team-02-en ]] || exit 1
source "$BASE/conf/hw2/hadoop-env.sh"

export SPARK_HOME=$BASE/software/spark-3.5.7
export HIVE_HOME=$BASE/software/hive-2.3.9
export HIVE_CONF_DIR=$BASE/conf/hw4
export SPARK_CONF_DIR=$HIVE_CONF_DIR
export YARN_CONF_DIR=$HADOOP_CONF_DIR
export SPARK_LOCAL_IP=10.2.0.10
export SPARK_LOCAL_DIRS=$BASE/tmp/hw4/spark
export SPARK_SUBMIT_OPTS="-Djava.io.tmpdir=$BASE/tmp/hw4 -Djdk.net.hosts.file=$BASE/conf/hw2/hosts"

mkdir -p "$HIVE_CONF_DIR" "$BASE/data/hw4" "$BASE/logs/hw4" \
  "$BASE/tmp/hw4/spark" "$BASE/tmp/hw4/hive"

for port in 22340 22342 22343 22344 {22350..22355}; do
  if ss -ltnH | grep -Eq ":${port}[[:space:]]"; then
    echo "Port $port is already in use" >&2
    exit 1
  fi
done

python3 "$ROOT/hw4/install.py"

cat > "$HIVE_CONF_DIR/hive-site.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property><name>javax.jdo.option.ConnectionURL</name><value>jdbc:derby:;databaseName=/srv/dpe/ksenia/data/hw4/metastore_db;create=true</value></property>
  <property><name>javax.jdo.option.ConnectionDriverName</name><value>org.apache.derby.jdbc.EmbeddedDriver</value></property>
  <property><name>hive.metastore.schema.verification</name><value>true</value></property>
  <property><name>hive.metastore.warehouse.dir</name><value>hdfs:///user/dpe_ksenia/hw4/warehouse</value></property>
  <property><name>hive.exec.scratchdir</name><value>hdfs:///user/dpe_ksenia/hw4/scratch</value></property>
  <property><name>hive.exec.local.scratchdir</name><value>/srv/dpe/ksenia/tmp/hw4/hive</value></property>
  <property><name>hive.querylog.location</name><value>/srv/dpe/ksenia/logs/hw4</value></property>
  <property><name>hive.exec.dynamic.partition</name><value>true</value></property>
  <property><name>hive.exec.dynamic.partition.mode</name><value>nonstrict</value></property>
</configuration>
XML

cat > "$SPARK_CONF_DIR/spark-defaults.conf" <<'CONF'
spark.master yarn
spark.submit.deployMode client
spark.driver.host 10.2.0.10
spark.driver.bindAddress 10.2.0.10
spark.driver.port 22342
spark.blockManager.port 22350
spark.ui.port 22340
spark.yarn.am.port 22343
spark.executor.port 22344
spark.port.maxRetries 5
spark.driver.memory 768m
spark.executor.memory 512m
spark.executor.instances 1
spark.executor.cores 1
spark.yarn.am.memory 512m
spark.sql.shuffle.partitions 2
spark.sql.warehouse.dir hdfs:///user/dpe_ksenia/hw4/warehouse
spark.yarn.stagingDir hdfs:///user/dpe_ksenia/hw4/staging
spark.yarn.am.extraJavaOptions -Djdk.net.hosts.file=/srv/dpe/ksenia/conf/hw2/hosts
spark.executor.extraJavaOptions -Djdk.net.hosts.file=/srv/dpe/ksenia/conf/hw2/hosts
spark.yarn.appMasterEnv.JAVA_HOME /srv/dpe/ksenia/software/java11
spark.executorEnv.JAVA_HOME /srv/dpe/ksenia/software/java11
CONF

"$HADOOP_HOME/bin/hdfs" dfs -mkdir -p \
  /user/dpe_ksenia/hw4/input \
  /user/dpe_ksenia/hw4/staging \
  /user/dpe_ksenia/hw4/warehouse \
  /user/dpe_ksenia/hw4/scratch
"$HADOOP_HOME/bin/hdfs" dfs -chmod 733 /user/dpe_ksenia/hw4/scratch
"$HADOOP_HOME/bin/hdfs" dfs -put -f "$ROOT/hw4/orders.csv" \
  /user/dpe_ksenia/hw4/input/orders.csv
"$HADOOP_HOME/bin/hdfs" dfs -ls /user/dpe_ksenia/hw4/input/orders.csv

if [[ ! -d "$BASE/data/hw4/metastore_db" ]]; then
  "$HIVE_HOME/bin/schematool" -dbType derby -initSchema
fi

"$SPARK_HOME/bin/spark-submit" "$ROOT/hw4/job.py"

"$HIVE_HOME/bin/hive" -S -e '
SHOW PARTITIONS ksenia_hw4.orders_by_city;
SELECT city, orders, total_amount, order_month
FROM ksenia_hw4.orders_by_city
LIMIT 10;
'
