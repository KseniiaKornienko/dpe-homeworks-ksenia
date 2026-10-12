import argparse
from pathlib import Path
import socket
import xml.etree.ElementTree as ET
from settings import BASE, CONFIG, NODES, PORTS as P, VERSIONS


def xml_file(path, values):
    root = ET.Element("configuration")
    for key, value in values.items():
        prop = ET.SubElement(root, "property")
        ET.SubElement(prop, "name").text = key
        ET.SubElement(prop, "value").text = str(value)
    ET.indent(root, space="  ")
    ET.ElementTree(root).write(path, encoding="utf-8", xml_declaration=True)


def render(role, output=None):
    ip = NODES[role]["ip"]
    nn, edge = NODES["namenode"]["ip"], NODES["edge"]["ip"]
    software = BASE + "/software"
    hadoop = software + "/hadoop-" + VERSIONS["hadoop"]["version"]
    java = software + "/java11"
    hosts_option = "-Djdk.net.hosts.file=" + BASE + "/conf/hw2/hosts"
    core = {"fs.defaultFS": f"hdfs://{nn}:{P['nn_rpc']}",
            "hadoop.tmp.dir": BASE + "/tmp/hw1/hadoop",
            "hadoop.security.authentication": "simple"}
    hdfs = {
        "dfs.replication": 3,
        "dfs.namenode.name.dir": "file://" + BASE + "/data/hw1/namenode",
        "dfs.datanode.data.dir": "file://" + BASE + "/data/hw1/datanode",
        "dfs.namenode.checkpoint.dir": "file://" + BASE + "/data/hw1/checkpoint",
        "dfs.namenode.checkpoint.edits.dir": "file://" + BASE + "/data/hw1/checkpoint-edits",
        "dfs.namenode.rpc-address": f"{nn}:{P['nn_rpc']}",
        "dfs.namenode.http-address": f"{nn}:{P['nn_http']}",
        "dfs.namenode.secondary.http-address": f"{NODES['edge']['host']}:{P['snn_http']}",
        "dfs.datanode.address": f"{ip}:{P['dn_transfer']}",
        "dfs.datanode.ipc.address": f"{ip}:{P['dn_ipc']}",
        "dfs.datanode.http.address": f"{ip}:{P['dn_http']}",
        "dfs.datanode.http.internal-proxy.port": P["dn_internal_http"],
        "dfs.client.use.datanode.hostname": "false",
        "dfs.datanode.use.datanode.hostname": "false",
        "dfs.namenode.checkpoint.period": 60,
        "dfs.namenode.checkpoint.txns": 10,
        "dfs.webhdfs.enabled": "true",
    }
    yarn = {
        "yarn.resourcemanager.hostname": edge,
        "yarn.resourcemanager.bind-host": edge,
        "yarn.resourcemanager.address": f"{edge}:{P['rm_client']}",
        "yarn.resourcemanager.scheduler.address": f"{edge}:{P['rm_scheduler']}",
        "yarn.resourcemanager.resource-tracker.address": f"{edge}:{P['rm_tracker']}",
        "yarn.resourcemanager.admin.address": f"{edge}:{P['rm_admin']}",
        "yarn.resourcemanager.webapp.address": f"{edge}:{P['rm_http']}",
        "yarn.nodemanager.hostname": ip,
        "yarn.nodemanager.bind-host": ip,
        "yarn.nodemanager.address": f"{ip}:{P['nm_rpc']}",
        "yarn.nodemanager.localizer.address": f"{ip}:{P['nm_localizer']}",
        "yarn.nodemanager.webapp.address": f"{ip}:{P['nm_http']}",
        "yarn.nodemanager.aux-services": "mapreduce_shuffle",
        "mapreduce.shuffle.port": P["shuffle"],
        "yarn.nodemanager.local-dirs": BASE + "/data/hw2/nm-local",
        "yarn.nodemanager.log-dirs": BASE + "/logs/hw2/containers",
        "yarn.nodemanager.resource.memory-mb": 1024,
        "yarn.nodemanager.resource.cpu-vcores": 1,
        "yarn.scheduler.minimum-allocation-mb": 384,
        "yarn.scheduler.maximum-allocation-mb": 1024,
        "yarn.scheduler.maximum-allocation-vcores": 1,
        "yarn.nodemanager.vmem-check-enabled": "false",
        "yarn.nodemanager.env-whitelist": "JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME,PATH,LANG,TZ",
        "yarn.web-proxy.address": f"{edge}:{P['web_proxy']}",
        "yarn.log-aggregation-enable": "true",
        "yarn.nodemanager.remote-app-log-dir": "/user/dpe_ksenia/hw2/app-logs",
        "yarn.nodemanager.remote-app-log-dir-suffix": "logs-ksenia",
        "yarn.application.classpath": ",".join([BASE + "/conf/hw2"] + [
            hadoop + "/share/hadoop/" + p for p in
            ("common/*", "common/lib/*", "hdfs/*", "hdfs/lib/*", "yarn/*", "yarn/lib/*")]),
    }
    mapred = {
        "mapreduce.framework.name": "yarn",
        "mapreduce.jobhistory.bind-host": edge,
        "mapreduce.jobhistory.address": f"{edge}:{P['history_rpc']}",
        "mapreduce.jobhistory.webapp.address": f"{edge}:{P['history_http']}",
        "mapreduce.jobhistory.admin.address": f"{edge}:{P['history_admin']}",
        "mapreduce.jobhistory.done-dir": "/user/dpe_ksenia/hw2/history/done",
        "mapreduce.jobhistory.intermediate-done-dir": "/user/dpe_ksenia/hw2/history/intermediate",
        "yarn.app.mapreduce.am.staging-dir": "/user/dpe_ksenia/hw2/staging",
        "yarn.app.mapreduce.am.job.client.port-range": CONFIG["am_rpc_range"],
        "yarn.app.mapreduce.am.webapp.port-range": CONFIG["am_web_range"],
        "yarn.app.mapreduce.am.resource.mb": 384,
        "yarn.app.mapreduce.am.command-opts": "-Xmx192m " + hosts_option,
        "mapreduce.map.memory.mb": 384,
        "mapreduce.map.java.opts": "-Xmx192m " + hosts_option,
        "mapreduce.reduce.memory.mb": 384,
        "mapreduce.reduce.java.opts": "-Xmx192m " + hosts_option,
        "mapreduce.map.maxattempts": 1,
        "mapreduce.reduce.maxattempts": 1,
        "mapreduce.job.reduces": 1,
        "yarn.app.mapreduce.am.env": "JAVA_HOME=" + java,
        "mapreduce.map.env": "JAVA_HOME=" + java,
        "mapreduce.reduce.env": "JAVA_HOME=" + java,
        "mapreduce.application.classpath": hadoop + "/share/hadoop/mapreduce/*," + hadoop + "/share/hadoop/mapreduce/lib/*",
    }
    for hw in ("hw1", "hw2"):
        target = Path(output) / hw if output else Path(BASE) / "conf" / hw
        target.mkdir(parents=True, exist_ok=True)
        if hw == "hw2":
            fqdn = socket.getfqdn()
            short = NODES[role]["host"]
            suffix = fqdn[len(short):] if fqdn.startswith(short + ".") else ""
            hosts = ["127.0.0.1 localhost", "::1 ip6-localhost"]
            for node in NODES.values():
                host = node["host"]
                aliases = [host, host + suffix] if suffix else [host]
                hosts.append(" ".join([node["ip"], *aliases]))
            hosts_path = target / "hosts"
            if hosts_path.is_symlink():
                raise ValueError("Refusing symlink hosts file")
            hosts_path.write_text("\n".join(hosts) + "\n")
        scope_core = dict(core)
        scope_core["hadoop.tmp.dir"] = BASE + "/tmp/" + hw + "/hadoop"
        xml_file(target / "core-site.xml", scope_core)
        xml_file(target / "hdfs-site.xml", hdfs)
        xml_file(target / "yarn-site.xml", yarn if hw == "hw2" else {})
        xml_file(target / "mapred-site.xml", mapred if hw == "hw2" else {})
        xml_file(target / "capacity-scheduler.xml", {
            "yarn.scheduler.capacity.root.queues": "default",
            "yarn.scheduler.capacity.root.default.capacity": 100,
            "yarn.scheduler.capacity.root.default.maximum-capacity": 100,
            "yarn.scheduler.capacity.root.default.acl_submit_applications": "dpe_ksenia",
            "yarn.scheduler.capacity.maximum-am-resource-percent": 0.5,
        })
        env = f'''export JAVA_HOME={java}
export HADOOP_HOME={hadoop}
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export HADOOP_YARN_HOME=$HADOOP_HOME
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_CONF_DIR={BASE}/conf/{hw}
export HADOOP_IDENT_STRING=dpe_ksenia
export HADOOP_LOG_DIR={BASE}/logs/{hw}
export HADOOP_PID_DIR={BASE}/pids/{hw}
export YARN_LOG_DIR=$HADOOP_LOG_DIR
export YARN_PID_DIR=$HADOOP_PID_DIR
export MAPRED_LOG_DIR=$HADOOP_LOG_DIR
export MAPRED_PID_DIR=$HADOOP_PID_DIR
export HADOOP_HEAPSIZE_MAX=256m
export HDFS_NAMENODE_OPTS="-Xmx384m"
export YARN_RESOURCEMANAGER_OPTS="-Xmx384m"
export YARN_NODEMANAGER_OPTS="-Xmx256m"
export YARN_PROXYSERVER_OPTS="-Xmx128m"
export MAPRED_HISTORYSERVER_OPTS="-Xmx256m"
export HADOOP_OPTS="-Djava.io.tmpdir={BASE}/tmp/{hw}{' ' + hosts_option if hw == 'hw2' else ''}"
export YARN_OPTS="$HADOOP_OPTS"
export HADOOP_CLIENT_OPTS="$HADOOP_OPTS"
export TMPDIR={BASE}/tmp/{hw}
export PATH=$JAVA_HOME/bin:$HADOOP_HOME/bin:$PATH
'''
        (target / "hadoop-env.sh").write_text(env)
        (target / "yarn-env.sh").write_text("")
        (target / "mapred-env.sh").write_text("")
        (target / "workers").write_text("\n".join(NODES[r]["ip"] for r in ("edge", "worker0", "worker1")) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("role", choices=NODES)
    parser.add_argument("--output", help="Use a local directory to inspect configs without deploying")
    args = parser.parse_args()
    render(args.role, args.output)
