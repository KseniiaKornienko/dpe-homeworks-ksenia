# ДЗ 2: YARN и веб-интерфейсы

Для этого задания сначала нужен работающий HDFS из ДЗ 1. ResourceManager, JobHistoryServer и WebAppProxyServer запускаются на `team-02-en`. NodeManager работают на `team-02-en`, `team-02-00` и `team-02-01`.

Команды из корня репозитория:

```bash
bash bootstrap.sh run yarn-start
bash bootstrap.sh run proxy-start
python3 common/port_table.py
```

Чтобы открыть интерфейсы на своём компьютере, в отдельном терминале выполните:

```bash
bash bootstrap.sh tunnel
```

Команда `python3 common/port_table.py` покажет адреса всех 11 интерфейсов. Для входа нужны учётные данные из файла, путь к которому выводит `proxy-start`. Их можно посмотреть на edge-ноде, подставив выданный адрес:

```bash
EDGE_IP=YOUR_EDGE_IP
ssh -i ~/.ssh/mts_course "team@$EDGE_IP" 'sudo cat /srv/dpe/ksenia/conf/hw2/web/credentials.json'
```

Прокси использует самоподписанный сертификат. [Результат](RESULTS.md).
