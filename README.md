# ДЗ 1, 2, 3 и 4: HDFS, YARN, Hive и Spark

Здесь решения заданий по [HDFS](hw1/README.md), [YARN](hw2/README.md), [Hive](hw3/README.md) и [Spark](hw4/README.md). В каждой папке есть инструкция и скрипты. Общие файлы для установки и настройки лежат в `bootstrap.sh` и `common/`.

## Подготовка

Для запуска нужен SSH-доступ к edge-ноде. На ВМ должны быть Python 3.12, `tar`, `ss` и `openssl`. Внутренний ключ `team_internal` уже находится на edge-ноде.

1. Скопировать `common/cluster.example.json` в `common/cluster.json` и указать выданный адрес edge-ноды в `public_host`.
2. Создать `common/known_hosts` с проверенным SSH host key edge-ноды.
3. Добавить SSH-ключ в `ssh-agent`. По умолчанию скрипт ищет `~/.ssh/mts_course`; если он лежит в другом месте, нужно задать `DPE_SSH_KEY`.
4. Из корня репозитория выполнить:

```bash
bash bootstrap.sh setup
```

`setup` подготовит ВМ и установит Java и Hadoop.

## Запуск

Сначала запускается [ДЗ 1](hw1/README.md):

```bash
bash bootstrap.sh run hdfs-start
```

Затем [ДЗ 2](hw2/README.md):

```bash
bash bootstrap.sh run yarn-start
bash bootstrap.sh run proxy-start
```

Для доступа к веб-интерфейсам с компьютера запустите в отдельном терминале `bash bootstrap.sh tunnel`. Команда `python3 common/port_table.py` покажет адреса всех интерфейсов на `localhost`. [Результат ДЗ 2](hw2/RESULTS.md).

Для ДЗ 3 после запуска HDFS выполнить `bash bootstrap.sh run hw3-run`. [Инструкция](hw3/README.md) и [результат](hw3/RESULTS.md).

Для ДЗ 4 после запуска HDFS и YARN выполнить `bash bootstrap.sh run hw4-run`. [Инструкция](hw4/README.md) и [результат](hw4/RESULTS.md).
