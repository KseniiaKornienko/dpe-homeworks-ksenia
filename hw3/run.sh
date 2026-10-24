#!/usr/bin/env bash
set -euo pipefail

BASE=/srv/dpe/ksenia
ROOT=$BASE/homeworks
[[ $(id -un) == dpe_ksenia && $(hostname -s) == team-02-en ]] || exit 1
source "$BASE/conf/hw2/hadoop-env.sh"

export HIVE_HOME=$BASE/software/hive-2.3.9
export DERBY_HOME=$BASE/software/derby-10.10.2.0
export HIVE_CONF_DIR=$BASE/conf/hw3
export HIVE_AUX_JARS_PATH=$DERBY_HOME/lib/derbyclient.jar
export HADOOP_HEAPSIZE=512
export HADOOP_CLIENT_OPTS="$HADOOP_CLIENT_OPTS -Djava.io.tmpdir=$BASE/tmp/hw3"

mkdir -p "$HIVE_CONF_DIR" "$BASE/data/hw3" "$BASE/logs/hw3" \
  "$BASE/pids/hw3" "$BASE/tmp/hw3/hive"

for port in 22400 22401 22402; do
  if ss -ltnH | grep -Eq ":${port}[[:space:]]"; then
    echo "Port $port is already in use" >&2
    exit 1
  fi
done

python3 "$ROOT/hw3/install.py"

cat > "$HIVE_CONF_DIR/hive-site.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property><name>javax.jdo.option.ConnectionURL</name><value>jdbc:derby://127.0.0.1:22400/metastore_db;create=true</value></property>
  <property><name>javax.jdo.option.ConnectionDriverName</name><value>org.apache.derby.jdbc.ClientDriver</value></property>
  <property><name>hive.metastore.schema.verification</name><value>true</value></property>
  <property><name>hive.metastore.uris</name><value>thrift://127.0.0.1:22401</value></property>
  <property><name>hive.metastore.port</name><value>22401</value></property>
  <property><name>hive.metastore.warehouse.dir</name><value>hdfs:///user/dpe_ksenia/hw3/warehouse</value></property>
  <property><name>hive.exec.scratchdir</name><value>hdfs:///user/dpe_ksenia/hw3/scratch</value></property>
  <property><name>hive.exec.local.scratchdir</name><value>/srv/dpe/ksenia/tmp/hw3/hive</value></property>
  <property><name>hive.querylog.location</name><value>/srv/dpe/ksenia/logs/hw3</value></property>
  <property><name>hive.server2.thrift.bind.host</name><value>127.0.0.1</value></property>
  <property><name>hive.server2.thrift.port</name><value>22402</value></property>
  <property><name>hive.server2.enable.doAs</name><value>false</value></property>
  <property><name>hive.server2.webui.port</name><value>0</value></property>
</configuration>
XML

"$HADOOP_HOME/bin/hdfs" dfs -mkdir -p \
  /user/dpe_ksenia/hw3/input \
  /user/dpe_ksenia/hw3/warehouse \
  /user/dpe_ksenia/hw3/scratch
"$HADOOP_HOME/bin/hdfs" dfs -chmod 733 /user/dpe_ksenia/hw3/scratch
"$HADOOP_HOME/bin/hdfs" dfs -put -f "$ROOT/hw3/orders_2026-09.csv" \
  /user/dpe_ksenia/hw3/input/orders_2026-09.csv
"$HADOOP_HOME/bin/hdfs" dfs -put -f "$ROOT/hw3/orders_2026-10.csv" \
  /user/dpe_ksenia/hw3/input/orders_2026-10.csv

stop_services() {
  for name in hiveserver2 metastore derby; do
    pidfile=$BASE/pids/hw3/$name.pid
    [[ -f "$pidfile" ]] || continue
    pid=$(cat "$pidfile")
    if [[ "$pid" =~ ^[0-9]+$ ]]; then
      user=$(ps -o user= -p "$pid" | tr -d ' ' || true)
      pgid=$(ps -o pgid= -p "$pid" | tr -d ' ' || true)
      command=$(ps -o args= -p "$pid" || true)
      if [[ "$user" == dpe_ksenia && "$pgid" == "$pid" && "$command" == *"$BASE/"* ]]; then
        kill -- "-$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
      fi
    fi
    rm -f "$pidfile"
  done
}
trap stop_services EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

start_service() {
  name=$1
  shift
  setsid "$@" > "$BASE/logs/hw3/$name.log" 2>&1 &
  echo $! > "$BASE/pids/hw3/$name.pid"
}

wait_port() {
  name=$1
  port=$2
  pid=$(cat "$BASE/pids/hw3/$name.pid")
  for _ in {1..180}; do
    if ss -ltnH | grep -Eq ":${port}[[:space:]]"; then
      return
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      tail -n 30 "$BASE/logs/hw3/$name.log" >&2
      return 1
    fi
    sleep 1
  done
  tail -n 30 "$BASE/logs/hw3/$name.log" >&2
  return 1
}

start_service derby "$JAVA_HOME/bin/java" \
  "-Dderby.system.home=$BASE/data/hw3" \
  -jar "$DERBY_HOME/lib/derbyrun.jar" server start -h 127.0.0.1 -p 22400
wait_port derby 22400

if [[ ! -f "$BASE/data/hw3/metastore-schema.done" ]]; then
  "$HIVE_HOME/bin/schematool" -dbType derby -initSchema
  touch "$BASE/data/hw3/metastore-schema.done"
fi

start_service metastore "$HIVE_HOME/bin/hive" --service metastore -p 22401
wait_port metastore 22401
start_service hiveserver2 "$HIVE_HOME/bin/hive" --service hiveserver2
wait_port hiveserver2 22402

BEELINE=("$HIVE_HOME/bin/beeline" -u jdbc:hive2://127.0.0.1:22402/default \
  -n dpe_ksenia --silent=true --showHeader=false --outputformat=tsv2)

ready=false
for _ in {1..12}; do
  if "${BEELINE[@]}" -e 'SHOW DATABASES;' > /dev/null 2> "$BASE/logs/hw3/readiness.err"; then
    ready=true
    break
  fi
  sleep 5
done
if [[ "$ready" != true ]]; then
  tail -n 30 "$BASE/logs/hw3/readiness.err" >&2
  exit 1
fi

"${BEELINE[@]}" -e "
DROP DATABASE IF EXISTS ksenia_hw3 CASCADE;
CREATE DATABASE ksenia_hw3 LOCATION 'hdfs:///user/dpe_ksenia/hw3/warehouse/ksenia_hw3.db';
CREATE TABLE ksenia_hw3.orders (
  order_id INT,
  city STRING,
  amount DECIMAL(10,2)
)
PARTITIONED BY (order_month STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE;
LOAD DATA INPATH 'hdfs:///user/dpe_ksenia/hw3/input/orders_2026-09.csv'
  INTO TABLE ksenia_hw3.orders PARTITION (order_month='2026-09');
LOAD DATA INPATH 'hdfs:///user/dpe_ksenia/hw3/input/orders_2026-10.csv'
  INTO TABLE ksenia_hw3.orders PARTITION (order_month='2026-10');
"

"${BEELINE[@]}" -e 'SHOW PARTITIONS ksenia_hw3.orders;' \
  > "$BASE/logs/hw3/client1.out" 2> "$BASE/logs/hw3/client1.err" &
client1=$!
"${BEELINE[@]}" -e 'SELECT order_id, city, amount, order_month FROM ksenia_hw3.orders LIMIT 10;' \
  > "$BASE/logs/hw3/client2.out" 2> "$BASE/logs/hw3/client2.err" &
client2=$!
if ! wait "$client1"; then
  cat "$BASE/logs/hw3/client1.err" >&2
  exit 1
fi
if ! wait "$client2"; then
  cat "$BASE/logs/hw3/client2.err" >&2
  exit 1
fi

grep -Fq 'order_month=2026-09' "$BASE/logs/hw3/client1.out"
grep -Fq 'order_month=2026-10' "$BASE/logs/hw3/client1.out"
grep -Fq 'Moscow' "$BASE/logs/hw3/client2.out"
grep -Fq 'Kazan' "$BASE/logs/hw3/client2.out"
grep -Fq 'Perm' "$BASE/logs/hw3/client2.out"

printf 'Partitions:\n'
cat "$BASE/logs/hw3/client1.out"
printf 'Rows:\n'
cat "$BASE/logs/hw3/client2.out"
