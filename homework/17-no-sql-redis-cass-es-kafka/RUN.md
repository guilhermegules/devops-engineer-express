# Homework 17 - How to Run

Step-by-step runbook to provision **Redis**, **Elasticsearch**, **Cassandra** and
**Kafka** on a single host with the custom Ansible roles in this directory.

For the design/role reference see [`README.md`](README.md).

---

## 0. What you need

| Requirement | Notes |
|---|---|
| A Linux VM you can SSH into | e.g. the Ubuntu VM from Homework 08 (`10.0.0.10`) |
| SSH access as a sudo-capable user | defaults to `vagrant` + the insecure Vagrant key |
| Ansible on the controller | install below |
| ~4 GB RAM on the VM | Elasticsearch 1 GB + Cassandra 1 GB + Kafka 512 MB + Redis 256 MB |
| Outbound network on the VM | `artifacts.elastic.co`, `debian.cassandra.apache.org`, `archive.apache.org` |

---

## 1. Install Ansible (controller machine)

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv

python3 -m venv ~/ansible-venv
source ~/ansible-venv/bin/activate
pip install ansible

ansible --version
```

> On Windows use WSL2 and keep the project under `~/` for better I/O.

---

## 2. Enter the homework directory

```bash
cd homework/17-no-sql-redis-cass-es-kafka
```

---

## 3. Point the inventory at your host

Edit `inventory/hosts.ini`:

```ini
[all:vars]
ansible_user=vagrant
ansible_ssh_private_key_file=~/.vagrant.d/insecure_private_key
ansible_python_interpreter=/usr/bin/python3

[nosql]
vm1 ansible_host=10.0.0.10
```

Change `ansible_host`, `ansible_user` and the key path to match your VM.

---

## 4. Test connectivity

```bash
ansible nosql -i inventory/hosts.ini -m ping
```

Expect `pong`. If this fails, fix SSH before continuing.

---

## 5. Provision everything

```bash
ansible-playbook -i inventory/hosts.ini playbook.yml
```

This runs the roles in order: `common` -> `redis` -> `elasticsearch` -> `cassandra` -> `kafka`.
Each `systemd` service is enabled, so the stack returns after a reboot.

Useful variants:

```bash
ansible-playbook playbook.yml --check --diff     # dry run
ansible-playbook playbook.yml --tags redis       # only one service
ansible-playbook playbook.yml --tags elasticsearch
ansible-playbook playbook.yml --tags cassandra
ansible-playbook playbook.yml --tags kafka
ansible-playbook playbook.yml -vvv               # debug
```

The first run downloads the Elastic/Cassandra packages and the ~120 MB Kafka
tarball, so it can take several minutes.

---

## 6. Verify the stack

```bash
./scripts/verify-nosql.sh
```

Checks Redis `PING`, the Elasticsearch `_cluster/health` endpoint, Cassandra's
native port `9042`, and that the Kafka broker answers `--list`.

Manual checks:

```bash
ansible nosql -i inventory/hosts.ini -b -m shell -a "redis-cli ping"
ansible nosql -i inventory/hosts.ini -b -m shell -a "curl -s http://127.0.0.1:9200/_cluster/health?pretty"
ansible nosql -i inventory/hosts.ini -b -m shell -a "nodetool status"
ansible nosql -i inventory/hosts.ini -b -m shell -a "/opt/kafka/bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --list"
```

Or from inside the VM:

```bash
redis-cli -p 6379 ping                       # PONG
curl http://127.0.0.1:9200/_cluster/health   # green/yellow
nodetool status                              # UN  <ip>
/opt/kafka/bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --list
```

---

## 7. Exercise the sample clients (optional)

```bash
# Redis counter service on :9090
cd source/nosql/redis && go run go-redis-sample.go

# Cassandra keyspace + table, then read it back
cqlsh 127.0.0.1 9042 -f source/nosql/cassandra/keyspace.cql
cd source/nosql/cassandra && go run go-cass-sample.go

# Kafka smoke test
/opt/kafka/bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 \
  --create --topic homework --partitions 1 --replication-factor 1
```

---

## 8. Re-run safely / change config

The roles are idempotent: a second `ansible-playbook` run reports no changes.
Edit any value in `roles/<role>/defaults/main.yml` or
`inventory/group_vars/all.yml` and run the playbook again to apply it.

Common overrides:

| Variable | File | Default |
|---|---|---|
| `redis_bind` | `roles/redis/defaults/main.yml` | `127.0.0.1` |
| `elasticsearch_heap_size` | `roles/elasticsearch/defaults/main.yml` | `1g` |
| `cassandra_max_heap` | `roles/cassandra/defaults/main.yml` | `1G` |
| `kafka_version` | `roles/kafka/defaults/main.yml` | `3.9.2` |
| `kafka_advertised_host` | `roles/kafka/defaults/main.yml` | `127.0.0.1` |

---

## 9. Troubleshooting

| Symptom | Fix |
|---|---|
| `ansible ping` fails | Wrong `ansible_host`/user/key in `inventory/hosts.ini`; try `ssh` manually first. |
| Elasticsearch exits immediately | Check `vm.max_map_count` (`sysctl vm.max_map_count` -> `262144`) and that ~1 GB RAM is free. Re-run the playbook. |
| Elasticsearch yellow/green but `curl` refused | It binds `127.0.0.1`; test on the VM, or set `elasticsearch_network_host: 0.0.0.0`. |
| Cassandra never opens `9042` | It is slow to boot; give it 1-3 min. `journalctl -u cassandra -n 100`. Lower `cassandra_max_heap` if OOM-killed. |
| Kafka won't start | `systemctl status kafka` / `journalctl -u kafka -n 100`; confirm Java is present (`java -version`). |
| Playbook fails on the Kafka tarball | The VM needs outbound access to `archive.apache.org`. |
| No changes but service down | `systemctl status <redis-server\|elasticsearch\|cassandra\|kafka>`. |

Handlers apply config changes; if a service still uses old settings, restart it:

```bash
ansible nosql -i inventory/hosts.ini -b -m systemd -a "name=cassandra state=restarted"
```

---

## 10. Teardown (optional)

```bash
ansible nosql -i inventory/hosts.ini -b -m shell -a "systemctl stop kafka cassandra elasticsearch redis-server"
```

Remove packages/data on the VM as needed:

```bash
sudo apt-get remove --purge -y elasticsearch cassandra redis-server
sudo rm -rf /opt/kafka /opt/kafka-* /etc/kafka /var/lib/kafka
```
