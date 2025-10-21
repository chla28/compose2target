# compose2target

A tool to convert a 'podman compose' file to a target file like a 'podman run' command, a .container (quadlet) file, ...

Why this tool ?

I've unsuccessfully searched a tool able to generate multiple outputs with only one file (two with mapping).
**podlet** or **kustomize** are not able to generated a quadlet configuration or pacemaker command for example.
Perhaps, my needs are very specific...

With compose2target, you need only one valid compose file and the tools will be able to generate a 'run' command, a 'quadlet' file, a 'pcs' command to use with a pacemaker cluster, a 'k8s' file or an 'helm chart'.

+ If you have only one machine for your microservices, you'll use 'quadlet' or 'run' command
+ If you have two machines for your microservices, a pacemaker cluster is a good solution.
+ And if you have three or more machines, you'll use 'kubernetes' for your microservices.

Input can be a valid compose file or a valid compose file with an associated mapping file.

+ **compose_file** => **compose2target** => **target_file**

+ **compose_file_with_variables + mapping_file** => **compose2target** => **target_file**

+ **any_file_with_variable + mapping_file** => **compose2target** (mapping only option) => **output file** with variables replaced by their values present in input mapping_file

> [!IMPORTANT]
> This tool is still in development and not yet ready for production use.

> [!IMPORTANT]
> This tool is not for docker/docker-compose, it's for podman/podman-compose (rootless).

## Mapping file to replace variables in compose file:

Example:
+ In mapping file: **`MARIADB_PORT:"14306"`** and **`DBNAME=chladb`**
+ And in the input compose file: **`MARIADB_PORT: 3306`** and **`MYSQL_DATABSE=$DBNAME`**

In the final/output file:

+ Quadlet file: **`PublishPort=14306:3306`** and **`Environment=MYSQL_DATABASE="chladb"`**
+ run command:  **`-p 14306:3306`** and **`-e MYSQL_DATABASE="chladb"`**
+ compose file : **`- "14306:3306"`** and **`MYSQL_DATABASE="chladb"`**
+ pcs command : **`run_opts="-p 14306:3306 ... -e MYSQL_DATABASE=\"chladb\" ...`**

## Usage

### Without mapping

```
compose2target -i input_file.yaml -t <target> -o output_file.yaml
```

### With mapping

```
compose2target -i input_file.yaml -m mapping_file.yaml -t <target> -o output_file.yaml
```

### Targets list

- **run**: generate a "podman run" command
- **compose**: generate a "podman-compose" command
- **quadlet**: generate a "quadlet" container
- **pcs**: generate a "pcs" command to use in a Pacemaker cluster
- **k8s**: generate a "kubernetes" container [NOT YET IMPLEMENTED]
- **helm**: generate a "helm" container [NOT YET IMPLEMENTED]


## Example

## Generate a 'run' command from a compose file

File mariadb.yaml

```yaml
name: chla-pod1
services:
    mariadb-chla:
        labels:
            - description:"Database for demo"
        restart: always
        volumes:
            - /local/data/DB/Chla_DB: /var/lib/mysql/data
        ports:
            - 14306: 3306
        environment:
            - MYSQL_USER=chlauser
            - MYSQL_PASSWORD=chlauser1
            - MYSQL_DATABASE=chladb
        deploy:
            resources:
                limits:
                    cpus: 1
                    memory: 512M
                reservations:
                    cpus: '0.5'
                    memory: 256M
```

```bash
$ ./bin/compose2target -i compose_samples/mariadb.yaml  -t run -m mapping/mappingFile.yaml

podman run -d -it --name mariadb-chla\
    -p 14306:3306  \
    -e MYSQL_USER=chlauser -e MYSQL_PASSWORD=chlauser1 -e MYSQL_DATABASE=chladb  \
    -v /local/data/DB/Chla_DB:/var/lib/mysql/data:Z  \
    registry.redhat.io/rhel9/mariadb-1011:latest

$ podman run -d -it --name mariadb-chla\
    -p 14306:3306  \
    -e MYSQL_USER=chlauser -e MYSQL_PASSWORD=chlauser1 -e MYSQL_DATABASE=chladb  \
    -v /local/data/DB/Chla_DB:/var/lib/mysql/data:Z  \
    registry.redhat.io/rhel9/mariadb-1011:latest
58d5dfdc09a4580a09c67659f3feb587381761ca59d3f6ebab13816a41f19673
$ podman ps
CONTAINER ID  IMAGE                                         COMMAND     CREATED        STATUS        PORTS                    NAMES
58d5dfdc09a4  registry.redhat.io/rhel9/mariadb-1011:latest  run-mysqld  2 seconds ago  Up 3 seconds  0.0.0.0:14306->3306/tcp  mariadb-chla
$
```

## generate a 'compose' file from a compose file (with mapping)

```bash
$ ./bin/compose2target -i compose_samples/mariadb.yaml  -t compose -m mappin
g/mappingFile.yaml -o mariadb_compose.yaml
$ cat mariadb_compose.yaml
name: chla-pod1
services:
  mariadb-chla:
    container_name: mariadb-chla
    image: registry.redhat.io/rhel9/mariadb-1011:latest
    labels:
      - mariadb-chla.description="Database for demo"
      - mariadb-chla.comment="Chla Configuration"
    restart: always
    ports:
      - "14306:3306"
    environment:
      - MYSQL_USER=chlauser
      - MYSQL_PASSWORD=chlauser1
      - MYSQL_DATABASE=chladb
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: "512M"
        reservations:
          cpus: "0.5"
          memory: "256M"
    volumes:
      - /local/data/DB/Chla_DB:/var/lib/mysql/data:Z
$
```

## Generate a 'quadlet' command (.container file)from a compose file

> [!IMPORTANT]
> Pod pod_chla-pod1.pod is not created.

```bash
$ ./bin/compose2target -i compose_samples/mariadb.yaml  -t quadlet -m mapping/mappingFile.yaml -o mariadb.container
$ cat mariadb.container
[Unit]
Description=mariadb-chla

[Container]
ContainerName=mariadb-chla
Pod=pod_chla-pod1.pod
AutoUpdate=registry
Image=registry.redhat.io/rhel9/mariadb-1011:latest
PublishPort=14306:3306
Environment=MYSQL_USER=chlauser
Environment=MYSQL_PASSWORD=chlauser1
Environment=MYSQL_DATABASE=chladb
Volume=/local/data/DB/Chla_DB:/var/lib/mysql/data:Z

[Service]
Restart=always
RestartSec=5
Delegate=yes
MemorySwapMax=0
AllowedCPUs=1
MemoryMax=512M
CPUQuota=0.5
MemoryMin=256M

[Install]
WantedBy=default.target
$
```

To generate exe : dart compile exe bin/compose2target.dart -o compose2target


To execute:  ./bin/compose2target -i ./compose/compose_app_alm.yaml -m mappingFile.yaml -t run
             ./bin/compose2target -i ./compose/compose_app_alm.yaml -m mappingFile.yaml -t compose
