# ДЗ 3: Hive

Развернула отдельный Hive Metastore и HiveServer2. Данные метастора хранит Derby Network Server, поэтому с таблицей могут одновременно работать несколько клиентов.

Из корня репозитория выполнила:

```bash
bash bootstrap.sh setup
bash bootstrap.sh run hdfs-start
bash bootstrap.sh run hw3-run
```

Последняя команда устанавливает Hive и Derby, загружает [данные за сентябрь](orders_2026-09.csv) и [данные за октябрь](orders_2026-10.csv) в HDFS, создаёт таблицу `ksenia_hw3.orders` с партициями по месяцам и проверяет её через два клиента Beeline, запущенных одновременно. После проверки скрипт останавливает Hive и Derby. Команды приведены в [run.sh](run.sh), итог проверки — в [результате](RESULTS.md).

После работы остановила HDFS:

```bash
bash bootstrap.sh run hdfs-stop
```
