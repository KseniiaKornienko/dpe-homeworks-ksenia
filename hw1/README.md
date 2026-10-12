# ДЗ 1: HDFS

NameNode запускается на `team-02-nn`, SecondaryNameNode на `team-02-en`. DataNode работают на `team-02-en`, `team-02-00` и `team-02-01`.

Команды из корня репозитория:

```bash
bash bootstrap.sh setup
bash bootstrap.sh run hdfs-start
```

При первом запуске NameNode инициализируется. [Результат](RESULTS.md).

На самой edge-ноде HDFS можно запустить командой `bash hw1/hdfs.sh start` из каталога с файлами ДЗ.

Интерфейс NameNode можно открыть через SSH-туннель. В первой строке укажите выданный адрес edge-ноды:

```bash
EDGE_IP=YOUR_EDGE_IP
ssh -i ~/.ssh/mts_course -L 22870:10.2.0.11:22070 "team@$EDGE_IP"
```

После подключения откройте `http://localhost:22870/` и проверьте, что в списке есть три работающих DataNode и нет отключённых.
