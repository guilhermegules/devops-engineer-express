# Homework 17 - NoSQL: Redis, Cassandra, Elasticsearch, Kafka

Provision the four datastores from the assignment (`17-NoSQL-Redis-Cass-ES-Kafka.txt`)
with **Ansible**, using **one custom role per service**:

1. Create custom ansible ROLE in order to provision REDIS
2. Create custom ansible ROLE in order to provision ES
3. Create custom ansible ROLE in order to provision CASS
4. Create custom ansible ROLE in order to provision Kafka

The roles follow the same conventions as `../09-ansible`: `defaults/`, `tasks/`,
`handlers/`, `templates/`, an `inventory/` with `group_vars`, and an `ansible.cfg`
that points at the local inventory and roles.

## Project Structure

```
17-no-sql-redis-cass-es-kafka/
├── ansible.cfg                       # Ansible configuration
├── playbook.yml                      # Applies common + the four service roles
├── inventory/
│   ├── hosts.ini                     # [nosql] group (one host by default)
│   └── group_vars/all.yml            # Shared ports / host
├── roles/
│   ├── common/                       # Shared prerequisites (Java 11, curl, keyrings)
│   ├── redis/                        # Role 1 - Redis
│   ├── elasticsearch/                # Role 2 - Elasticsearch
│   │   └── templates/                #   elasticsearch.yml, jvm heap options
│   ├── cassandra/                    # Role 3 - Cassandra
│   └── kafka/                        # Role 4 - Kafka (KRaft)
│       └── templates/                #   server.properties, kafka.service
└── scripts/
    └── verify-nosql.sh               # Health-checks all four services
```

## Roles

| Role | Purpose |
|---|---|
| `common` | Shared prerequisites for the datastore roles: apt keyrings directory, `curl`, `gnupg`, and **Java 11** (used by Cassandra and Kafka; Elasticsearch ships its own bundled JDK). Works for both Debian and RedHat families. |
| `redis` | Installs Redis from the distro (`redis-server`/`redis`), sets bind address, protected mode, append-only persistence and a memory ceiling, then enables and starts the systemd service. |
| `elasticsearch` | Adds the official Elastic 8.x APT repository, installs `elasticsearch`, raises `vm.max_map_count`, writes `elasticsearch.yml` (single node, security off) and the JVM heap file, then starts the service and waits for `_cluster/health`. |
| `cassandra` | Adds the Apache Cassandra 4.1 APT repository, installs `cassandra`, sets cluster name / addresses / seeds / snitch / native port and the heap sizes, then starts the service and waits for port `9042`. |
| `kafka` | Installs the Apache Kafka tarball in `/opt/kafka`, creates a `kafka` system user, writes a single-node **KRaft** `server.properties`, formats the storage directory once, installs a `systemd` unit, and waits for the broker. |

## Architecture

```
                          +-------------------------------------------------+
                          |                [nosql] host                     |
                          |                                                 |
  source/nosql/redis  ---> |  Redis           127.0.0.1:6379   (role redis)  |
  (go-redis sample)       |                                                 |
                          |  Elasticsearch   127.0.0.1:9200   (role es)     |
                          |                                                 |
  source/nosql/cass   ---> |  Cassandra       0.0.0.0:9042     (role cass)   |
  (gocql sample)          |                                                 |
                          |  Kafka           127.0.0.1:9092   (role kafka)  |
                          +-------------------------------------------------+
```

The sample Go clients in `source/nosql/` connect to `localhost` on the default ports,
which is exactly where these roles make the services listen.

## Prerequisites

- Target host reachable over SSH with the user/keys set in `inventory/hosts.ini`
  (e.g. the Ubuntu VM from Homework 08, `10.0.0.10`).
- Ansible installed on the controller.
- Outbound access on the target to `artifacts.elastic.co`,
  `debian.cassandra.apache.org` and `archive.apache.org`.
- **RAM**: Elasticsearch ~1 GB heap + Cassandra ~1 GB heap + Kafka ~0.5 GB heap +
  Redis 256 MB. Give the VM ~4 GB to run all four comfortably.

### Installing Ansible

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv

python3 -m venv ~/ansible-venv
source ~/ansible-venv/bin/activate
pip install ansible

ansible --version
ansible all -i inventory/hosts.ini -m ping
```

## Usage

### 1. Provision the stack

```bash
ansible-playbook -i inventory/hosts.ini playbook.yml
```

The `common` role runs first, then `redis`, `elasticsearch`, `cassandra` and `kafka`.
Because every `systemd` service is enabled, the stack comes back after a reboot.

To provision a single service, use its tag:

```bash
ansible-playbook playbook.yml --tags redis
ansible-playbook playbook.yml --tags elasticsearch
ansible-playbook playbook.yml --tags cassandra
ansible-playbook playbook.yml --tags kafka
```

Dry-run and partial runs:

```bash
ansible-playbook playbook.yml --check --diff     # what would change
ansible-playbook playbook.yml --limit vm1        # one host
ansible-playbook playbook.yml -v                 # verbose
```

### 2. Verify it works

```bash
./scripts/verify-nosql.sh
```

The script runs ad-hoc commands over Ansible and checks:

- `redis-cli ping` returns `PONG`
- `curl http://127.0.0.1:9200/_cluster/health`
- something is listening on Cassandra's native port `9042`
- `kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --list` succeeds

Manual checks:

```bash
redis-cli -p 6379 ping
curl http://127.0.0.1:9200/_cluster/health?pretty
nodetool status
/opt/kafka/bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --list
```

### 3. Exercise the sample clients

The Go samples in `source/nosql/` are ready to use against this stack:

```bash
# Redis counter service on :9090
cd source/nosql/redis && go run go-redis-sample.go

# Cassandra keyspace + table, then read it back
cqlsh 127.0.0.1 9042 -f source/nosql/cassandra/keyspace.cql
cd source/nosql/cassandra && go run go-cass-sample.go

# Kafka smoke test
/opt/kafka/bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 \
  --create --topic homework --partitions 1 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server 127.0.0.1:9092 --list
```

## Configuration

Defaults live in each role's `roles/<role>/defaults/main.yml`; shared values live in
`inventory/group_vars/all.yml` and take precedence. Useful knobs:

| Variable | Role | Default |
|---|---|---|
| `redis_bind` | redis | `127.0.0.1` (set `0.0.0.0` for remote clients) |
| `redis_maxmemory` | redis | `256mb` |
| `elasticsearch_heap_size` | elasticsearch | `1g` |
| `elasticsearch_major` | elasticsearch | `8.x` |
| `cassandra_cluster_name` | cassandra | `NoSQL Homework Cluster` |
| `cassandra_max_heap` | cassandra | `1G` |
| `kafka_version` | kafka | `3.9.2` |
| `kafka_advertised_host` | kafka | `127.0.0.1` |

To expose a service beyond the VM, set its bind/advertised address to the VM IP (e.g.
`redis_bind: 0.0.0.0`, `kafka_advertised_host: 10.0.0.10`) and open the port in the
firewall.

## Design Notes

- **One role per datastore** is the point of the exercise, so each role owns its
  repository/key setup, its configuration template and its `systemd` lifecycle.
- **`common` is shared on purpose.** Java is the one prerequisite three of the four
  services need; duplicating it in each role would be worse. It is a helper, not one of
  the four deliverables.
- **Handlers + `meta: flush_handlers`.** Config changes notify a restart handler, and
  each role flushes handlers *before* starting its service so the first boot already
  uses the written configuration rather than the packaged defaults.
- **Kafka uses KRaft.** Modern Kafka (3.9) is run without ZooKeeper: the config gives
  the single node both the `broker` and `controller` roles, and the storage directory is
  formatted once with `kafka-storage.sh` (guarded by the presence of `meta.properties`,
  so re-runs skip it).
- **Idempotency.** Package installs, config templating, the Go-style "check then act"
  pattern for the Kafka tarball, and the storage-format guard all make a second
  `ansible-playbook` run report no changes.

## Gotchas found while building this

- **Elasticsearch refuses to start as root.** The Debian package creates an
  `elasticsearch` user and its own unit runs as that user; the role only writes config
  and lets the package own the process.
- **Elasticsearch needs `vm.max_map_count >= 262144`.** The role writes
  `/etc/sysctl.d/99-elasticsearch.conf` and reloads sysctl before the service starts.
- **The Elastic and Cassandra repos need a de-armored/armored key + `signed-by`.**
  Both keys are fetched with `get_url` and referenced from the `deb [...]` line.
- **Cassandra's YAML must keep its indentation.** The seed line is matched with
  `^(\s*)- seeds:` and rewritten with the captured indent so the list stays valid.
- **`listen_address` cannot be `0.0.0.0`.** Only `rpc_address` (native transport) is set
  to `0.0.0.0`; the internode listen address stays on `127.0.0.1` for the single node.
- **Kafka's start scripts need `java` on `PATH`.** `kafka-run-class.sh` falls back to
  `java` when `JAVA_HOME` is unset, and `common` installs Java 11, so the unit works
  without hard-coding a JDK path.
- **Kafka `--ignore-formatted`.** Even though the format task is guarded, passing
  `--ignore-formatted` makes the command safe if it is ever re-run.

## Provider Note

This homework targets a plain managed host (the VM from Homework 08). `redis` and
`kafka` handle both Debian and RedHat families; `elasticsearch` and `cassandra` install
from the official Debian/Ubuntu repositories (the target VM is Ubuntu), which is the
documented path for the assignment.
