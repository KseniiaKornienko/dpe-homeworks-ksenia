# ДЗ 4: Spark, YARN и Hive

Запустила Spark через YARN, прочитала CSV с заказами из HDFS и посчитала число заказов и сумму по городам и месяцам. Результат сохранила в таблицу Hive с партициями по месяцам.

Команды из корня репозитория:

```bash
bash bootstrap.sh setup
bash bootstrap.sh run hdfs-start
bash bootstrap.sh run yarn-start
bash bootstrap.sh run hw4-run
```

Последняя команда установит Spark и Hive, загрузит [orders.csv](orders.csv) в HDFS, запустит [обработку](job.py) через YARN и проверит таблицу через Hive. Скрипт запуска находится в [run.sh](run.sh), итоговые данные приведены в [результате](RESULTS.md).

После проверки остановить HDFS и YARN:

```bash
bash bootstrap.sh run yarn-stop
bash bootstrap.sh run hdfs-stop
```
