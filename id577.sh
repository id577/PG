#!/bin/bash

#VARIABLES
VERSION='0.2.6b'
NODE_EXPORTER_VERSION='1.2.2'
PROMETHEUS_VERSION='2.30.2'
GRAFANA_VERSION='8.1.5'
PUSHGATEWAY_VERSION='1.4.1'
LOKI_VERSION='2.3.0'
PROMTAIL_VERSION='2.3.0'

source ~/.bash_profile
if [ ! $IP_ADDRESS ]
	then 
	IP_ADDRESS=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
	if [ "$IP_ADDRESS" =  "" ]
		then
			is_correct=false
			while [ "$is_correct" = false ]; do
				read -p "IP-adress not defined. Please enter correct local IP-adress: " IP_ADDRESS
				IP_ADDRESS=$(echo $IP_ADDRESS | grep -oE "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)")
				if [ "$IP_ADDRESS" !=  "" ]
				then
					is_correct=true
				else
					echo -e "It doesn't look like an IP-address, please try again"
					sleep 1
				fi
			done
	fi
	echo 'export IP_ADDRESS='${IP_ADDRESS}  >> $HOME/.bash_profile
	source ~/.bash_profile
fi

echo -e "Your IP-address is: $IP_ADDRESS"
sleep 3

###################################################################################
function clearInstance {

EXPORTERS=("kira_pg" "nym_pg" "aleo_miner_pg" "aleo_pg" "zeitgeist_pg" "rizon_pg" "ironfish_pg" "massa_pg" "bitcountry_pg") 
 
for item in ${EXPORTERS[*]}
do
if [  -f "/etc/systemd/system/${item}.service" ]
	then
		echo -e "service ${item} founded! Deleting..."
		systemctl stop ${item} && systemctl disable ${item}
		rm -rf /usr/local/bin/${item}*
		rm -rf /etc/systemd/system/${item}*
		echo -e "service ${item} was successfully deleted!"
		echo -e ""
	else
		echo -e "service ${item} not founded."
		echo -e ""
fi
done
read -n 1 -s -r -p "Press any key to continue..."
}

###################################################################################
function installExporter {

echo -e "Node_exporter v${NODE_EXPORTER_VERSION} installation starts..."
sleep 3

CV=$(systemctl list-unit-files | grep "node_exporter.service")
if [ "$CV" != "" ]
then
	systemctl stop node_exporter
	rm -rf /etc/systemd/system/node_exporter* && rm -rf /usr/local/bin/node_exporter
fi

wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
tar xvf node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
cp node_exporter-$NODE_EXPORTER_VERSION.linux-amd64/node_exporter /usr/local/bin
rm -rf node_exporter*

sudo tee <<EOF >/dev/null /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && sudo systemctl enable node_exporter && sudo systemctl start node_exporter
sleep 3

VAR=$(systemctl is-active node_exporter.service)
if [ "$VAR" = "active" ]
then
	echo -e ""
	echo -e "node_exporter v$NODE_EXPORTER_VERSION \e[32minstalled and works\e[39m    ! Use curl -s http://$IP_ADDRESS:9100/metrics to check Node_exporter."
	echo -e "Dont't forget to add targets for your prometheus. Use 'sudo nano /etc/prometheus/prometheus.yml' on your server with prometheus."
	echo -e "For additional help go to https://prometheus.io/docs/prometheus/latest/getting_started/"
	echo -e ""
else
	echo -e ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u node_exporter -f"
	echo -e ""
fi


read -n 1 -s -r -p "Press any key to continue..."
}

###################################################################################
function installPrometheus {

echo -e "Prometheus v${PROMETHEUS_VERSION} installation starts..."
sleep 3

CV=$(systemctl list-unit-files | grep "prometheus")
if [ "$CV" != "" ]
then
	systemctl stop prometheus
fi

wget https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VERSION/prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
tar xfz prometheus-*.tar.gz
cd prometheus-$PROMETHEUS_VERSION.linux-amd64
sudo cp ./prometheus /usr/local/bin/
sudo cp ./promtool /usr/local/bin/
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus 
sudo cp -r ./consoles /etc/prometheus
sudo cp -r ./console_libraries /etc/prometheus
cd .. && rm -rf prometheus*

if [[ ! -f "/etc/prometheus/prometheus.yml" ]]
then
sudo tee <<EOF >/dev/null /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "weHaveNo.rules"

scrape_configs:
  - job_name: "prometheus"
    scrape_interval: 5s
    static_configs:
      - targets: ["localhost:9090"]
EOF
fi

sudo tee <<EOF >/dev/null /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/prometheus \
--web.enable-admin-api \
--config.file /etc/prometheus/prometheus.yml \
--storage.tsdb.path /var/lib/prometheus/ \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && sudo systemctl enable prometheus && sudo systemctl start prometheus
sleep 10

VAR=$(systemctl is-active prometheus.service)
if [ "$VAR" = "active" ]
then
	echo -e ""
	echo -e "Prometheus v$PROMETHEUS_VERSION \e[32minstalled and works\e[39m! Go to http://$IP_ADDRESS:9090/ to check it"
	echo -e ""
else
	echo -e ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u prometheus -f"
	echo -e ""
fi

read -n 1 -s -r -p "Press any key to continue..."
}

###################################################################################
function installGrafana {

echo -e "Grafana v${GRAFANA_VERSION} installation starts..."
sleep 3

sudo apt-get install -y adduser libfontconfig1
wget https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_amd64.deb
sudo dpkg -i grafana_${GRAFANA_VERSION}_amd64.deb
rm -rf grafana*

sudo systemctl daemon-reload && sudo systemctl enable grafana-server && sudo systemctl start grafana-server
sleep 10

VAR=$(systemctl is-active grafana.service)
if [ "$VAR" = "active" ]
then
	echo -e ""
	echo -e "Grafana v$GRAFANA_VERSION \e[32minstalled and works\e[39m! Go to http://$IP_ADDRESS:3000/ to enter grafana"
	echo -e "Don't forget to add data source in grafana interface. For additional help go to https://grafana.com/docs/grafana/latest/datasources/add-a-data-source/"
	echo -e ""
else
	echo -e ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u grafana -f"
	echo -e ""
fi

read -n 1 -s -r -p "Press any key to continue..."
}

###################################################################################
function installPushGateway {

echo -e "Pushgateway v${PUSHGATEWAY_VERSION} installation starts..."
sleep 3

wget https://github.com/prometheus/pushgateway/releases/download/v$PUSHGATEWAY_VERSION/pushgateway-$PUSHGATEWAY_VERSION.linux-amd64.tar.gz
tar xvfz pushgateway-$PUSHGATEWAY_VERSION.linux-amd64.tar.gz
sudo cp -r ./pushgateway-$PUSHGATEWAY_VERSION.linux-amd64/pushgateway /usr/local/bin/
rm -rf pushgateway*

sudo tee <<EOF >/dev/null /etc/systemd/system/pushgateway.service
[Unit]
Description=Prometheus Pushgateway
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/pushgateway

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && sudo systemctl enable pushgateway && sudo systemctl start pushgateway
sleep 3

VAR=$(systemctl is-active pushgateway.service)
if [ "$VAR" = "active" ]
then
	echo -e ""
	echo -e "Pushgateway 1.4.1 \e[32minstalled and works\e[39m!. Go to http://$IP_ADDRESS:9091 to check it."
	echo -e "Don't forget to add target (${IP}:9091) in your prometheus config file. Use 'sudo nano /etc/prometheus/prometheus.yml' on your server with prometheus"
	echo -e "Your pushgataway address: ${IP}:9091"
	echo -e ""
else
	echo -e ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u pushgataway -f"
	echo -e ""
fi

read -n 1 -s -r -p "Press any key to continue..."
}

###################################################################################
function installLoki {

echo -e "Loki v${LOKI_VERSION} installation starts..."
sleep 3

CV=$(systemctl list-unit-files | grep "loki")
if [ "$CV" != "" ]
then
	systemctl stop loki
fi

sudo curl -fSL -o loki.gz "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip"
sudo gunzip loki.gz
mkdir /etc/loki
mv loki /etc/loki
rm -rf loki*
chmod +x /etc/loki/loki

sudo tee <<EOF >/dev/null /etc/loki/loki-local-config.yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

ingester:
  wal:
    enabled: true
    dir: /tmp/wal
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 1h       # Any chunk not receiving new logs in this time will be flushed
  max_chunk_age: 1h           # All chunks will be flushed when they hit this age, default is 1h
  chunk_target_size: 1048576  # Loki will attempt to build chunks up to 1.5MB, flushing first if chunk_idle_period or max_chunk_age is reached first
  chunk_retain_period: 30s    # Must be greater than index read cache TTL if using an index cache (Default index read cache TTL is 5m)
  max_transfer_retries: 0     # Chunk transfers disabled

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /tmp/loki/boltdb-shipper-active
    cache_location: /tmp/loki/boltdb-shipper-cache
    cache_ttl: 24h         # Can be increased for faster performance over longer query periods, uses more disk space
    shared_store: filesystem
  filesystem:
    directory: /tmp/loki/chunks

compactor:
  working_directory: /tmp/loki/boltdb-shipper-compactor
  shared_store: filesystem

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s

ruler:
  storage:
    type: local
    local:
      directory: /tmp/loki/rules
  rule_path: /tmp/loki/rules-temp
  alertmanager_url: http://localhost:9093
  ring:
    kvstore:
      store: inmemory
  enable_api: true
EOF

sudo tee <<EOF >/dev/null /etc/systemd/system/loki.service
[Unit]
Description=Loki service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/etc/loki/loki -config.file /etc/loki/loki-local-config.yaml

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl enable loki && systemctl start loki
sleep 10

VAR=$(systemctl is-active loki.service)
if [ "$VAR" = "active" ]
then
	echo -e ""
	echo -e "loki v${LOKI_VERSION} \e[32minstalled and works\e[39m! You can check logs by: journalctl -u loki -f"
	echo -e "Don't forget to add data source (loki) in grafana interface."
	echo -e ""
else
	echo -e ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u loki -f"
	echo -e ""
fi

read -n 1 -s -r -p "Press any key to continue..."
}

###################################################################################
function installPromtail {

if [ ! $IP_LOKI ] 
then
	read -p "Enter loki IP-address and port (example: 142.198.11.12:3100): " IP_LOKI
	echo 'export IP_LOKI='${IP_LOKI} >> $HOME/.bash_profile
	source ~/.bash_profile
fi
if [ ! $JOB_NAME ] 
then
	read -p "Choose job_name: " JOB_NAME
	echo 'export JOB_NAME='${JOB_NAME} >> $HOME/.bash_profile
	source ~/.bash_profile
fi

echo -e "Promtail v${PROMTAIL_VERSION} installation starts..."
sleep 3

CV=$(systemctl list-unit-files | grep "promtail")
if [ "$CV" != "" ]
then
	echo -e "Founded promtail. Deleting..."
	systemctl stop promtail && systemctl disable promtail
	rm -rf /etc/promtail*
	rm -rf /etc/systemd/system/promtail*
fi

sudo curl -fSL -o promtail.gz "https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip"
sudo gunzip promtail.gz
mkdir /etc/promtail
mv promtail /etc/promtail
rm -rf ptomtail*
chmod +x /etc/promtail/promtail

sudo tee <<EOF >/dev/null /etc/promtail/promtail-local-config.yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://${IP_LOKI}/loki/api/v1/push

scrape_configs:
- job_name: containers
  static_configs:
  - targets:
      - localhost
    labels:
      job: ${JOB_NAME}_docker
      host: $IP_ADDRESS
      __path__: /var/lib/docker/containers/*/*log

  pipeline_stages:
  - json:
      expressions:
        output: log
        stream: stream
        attrs:
  - json:
      expressions:
        tag:
      source: attrs
  - regex:
      expression: (?P<container_name>(?:[^|]*[^|]))
      source: tag
  - timestamp:
      format: RFC3339Nano
      source: time
  - labels:
      # tag:
      stream:
      container_name:
  - output:
      source: output
      
- job_name: syslog
  journal:
    max_age: 12h
    labels:
      job: $JOB_NAME
      host: $IP_ADDRESS
  relabel_configs:
  - source_labels: ['__journal__systemd_unit']
    target_label: 'unit'
EOF

sudo tee <<EOF >/dev/null /etc/systemd/system/promtail.service
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/etc/promtail/promtail -config.file /etc/promtail/promtail-local-config.yaml

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl enable promtail && systemctl start promtail
sleep 3

VAR=$(systemctl is-active promtail.service)
if [ "$VAR" = "active" ]
then
	echo -e ""
	echo -e "Promtail v${PROMTAIL_VERSION} \e[32minstalled and works\e[39m! You can check logs by: journalctl -u promtail -f"
	echo -e ""
else
	echo -e ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u promtail -f"
	echo -e ""
fi

read -n 1 -s -r -p "Press any key to continue..."
}
###################################################################################
function installAleoExporter {

if [ ! $PUSHGATEWAY_ADDRESS ] 
then
	read -p "Enter your pushgateway ip-address (example: 142.198.11.12:9091 or leave empty if you don't use pushgateway): " PUSHGATEWAY_ADDRESS
	echo 'export PUSHGATEWAY_ADDRESS='${PUSHGATEWAY_ADDRESS} >> $HOME/.bash_profile
	source ~/.bash_profile
fi

echo -e "Aleo_exporter installation starts..."
sleep 3

aleo_service_name=""
aleo_miner_service_name=""

CV=$(systemctl list-unit-files | grep "aleo_exporter.service")
if [ "$CV" != "" ]
then
	echo -e "Founded aleo_exporter.service. Deleting..."
	systemctl stop aleo_exporter && systemctl disable aleo_exporter
	rm -rf /usr/local/bin/aleo_exporter.sh
	rm -rf /etc/systemd/system/aleo_exporter*
fi

CV=$(systemctl list-unit-files | grep "aleo.service")
if [ "$CV" != "" ]
then
	echo -e "aleo.service founded!"
	aleo_service_name="aleo.service"
fi

CV=$(systemctl list-unit-files | grep "aleod.service")
if [ "$CV" != "" ]
then
	echo -e "aleod.service founded!"
	aleo_service_name="aleod.service"
fi

CV=$(systemctl list-unit-files | grep "aleo-miner.service")
if [ "$CV" != "" ]
then
	echo -e "aleo-miner.service founded!"
	aleo_miner_service_name="aleo-miner.service"
fi

CV=$(systemctl list-unit-files | grep "aleod-miner.service")
if [ "$CV" != "" ]
then
	echo -e "aleod-miner.service founded!"
	aleo_miner_service_name="aleod-miner.service"
fi

if [ "$aleo_service_name" == "" ] && [ "$aleo_miner_service_name" == "" ]
then
	echo -e "No aleo service was founded. Are you sure that aleo is installed as a service?"
	echo -e "You can mannualy change variables 'aleo_service_name' 'aleo_miner_service_name' in script file /usr/local/bin/aleo_exporter"
	echo -e "if your aleo is not installed as a service, some metrics will not work!"
	read -n 1 -s -r -p "Press any key to continue or ctrl+c to abort installion"
fi

sudo tee <<EOF1 >/dev/null /usr/local/bin/aleo_exporter.sh
#!/bin/bash

PUSHGATEWAY_ADDRESS=$PUSHGATEWAY_ADDRESS
aleo_service_name="${aleo_service_name}"
aleo_miner_service_name="${aleo_miner_service_name}"
job="aleo"
metric_1='my_aleo_peers_count'
metric_2='my_aleo_status'
metric_3='my_aleo_blocks_count'
metric_4='my_aleo_is_synced'
metric_5='my_aleo_blocks_mined_count'
metric_6='my_aleo_miner_status'

function getMetrics {

peers_count=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getpeerinfo", "params": [] }' -H 'content-type: application/json' http://localhost:3030/ | grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" | wc -l)
if [ "\$peers_count" = "" ]
then peers_count=0
fi

is_synced=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getnodeinfo", "params": [] }' -H 'content-type: application/json' http://localhost:3030 | grep -E -o "is_syncing\":[A-Za-z]*" | grep -E -o "(true|false)")
if [ "\$is_synced" = "false" ]
then is_synced=1
else is_synced=0
fi

blocks_count=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getblockcount", "params": [] }' -H 'content-type: application/json' http://localhost:3030 | grep -E -o "result\":[0-9]*" | grep -E -o "[0-9]*")
if [ "\$blocks_count" = "" ]
then blocks_count=0
fi

if [ "\$aleo_service_name" != "" ] 
then is_active=\$(systemctl is-active ${aleo_service_name})
	if [ "\$is_active" = "active" ]
	then is_active=1
	else is_active=0
	fi
else is_active=0
fi

if [ "\$aleo_miner_service_name" != "" ] 
then is_active_miner=\$(systemctl is-active ${aleo_miner_service_name})
	if [ "\$is_active_miner" = "active" ]
	then is_active_miner=1
	else is_active_miner=0
	fi
else is_active_miner=0
fi

blocks_mined_count=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getnodestats", "params": [] }' -H 'content-type: application/json' http://localhost:3030 | grep -E -o "blocks_mined\":[0-9]*" | grep -E -o "[0-9]*")
if [ "\$blocks_mined_count" = "" ]
then blocks_mined_count=0
fi

#LOGS
echo -e "Aleo status report: aleo_is_active=\${is_active}, aleo_miner_is_active=\${is_active_miner}, is_synced=\${is_synced}, peers_count=\${peers_count}, blocks_count=\${blocks_count}, blocks_mined_count=\${blocks_mined_count}"

if [ "\$PUSHGATEWAY_ADDRESS" != "" ]
then
cat <<EOF | curl -s --data-binary @- \$PUSHGATEWAY_ADDRESS/metrics/job/\$job/instance/$IP_ADDRESS
# TYPE my_aleo_peers_count gauge
\$metric_1 \$peers_count
# TYPE my_aleo_status gauge
\$metric_2 \$is_active
# TYPE my_aleo_blocks_count gauge
\$metric_3 \$blocks_count
# TYPE my_aleo_is_synced gauge
\$metric_4 \$is_synced
# TYPE my_aleo_blocks_mined_count gauge
\$metric_5 \$blocks_mined_count
# TYPE my_aleo_miner_status gauge
\$metric_6 \$is_active_miner
EOF
echo -e "sended to pushgataway."
fi
}


while true; do
	getMetrics
	echo -e "sleep 60 sec."
	sleep 60
done
EOF1

chmod +x /usr/local/bin/aleo_exporter.sh

sudo tee <<EOF >/dev/null /etc/systemd/system/aleo_exporter.service
[Unit]
Description=Aleo Metrics Exporter
Wants=network-online.target
After=network-online.target
[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/aleo_exporter.sh
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && sudo systemctl enable aleo_exporter && sudo systemctl start aleo_exporter

VAR=$(systemctl is-active aleo_exporter.service)

if [ "$VAR" = "active" ]
then
	echo -e ""
	echo -e "aleo_exporter.service \e[32minstalled and works\e[39m! You can check logs by: journalctl -u aleo_exporter -f"
	echo -e ""
else
	echo -e ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u aleo_exporter -f"
	echo -e ""
fi
read -n 1 -s -r -p "Press any key to continue..."

}
###################################################################################
function installKiraExporter {

if [ ! $PUSHGATEWAY_ADDRESS ] 
then
	read -p "Enter your pushgateway ip-address (example: 142.198.11.12:9091 or leave empty if you don't use pushgateway): " PUSHGATEWAY_ADDRESS
	echo 'export PUSHGATEWAY_ADDRESS='${PUSHGATEWAY_ADDRESS} >> $HOME/.bash_profile
	source ~/.bash_profile
fi

echo -e "Kira_exporter installation starts..."
sleep 3

CV=$(systemctl list-unit-files | grep "kira_exporter.service")

if [ "$CV" != "" ]
then
	echo -e "Founded kira_exporter.service. Deleting..."
	systemctl stop kira_exporter && systemctl disable kira_exporter
	rm -rf /usr/local/bin/kira_exporter.sh
	rm -rf /etc/systemd/system/kira_exporter*
fi

if [ ! $KIRA_MONIKER ]
then
	read -p "Enter Moniker of your node: " KIRA_MONIKER
	echo 'export KIRA_MONIKER='${KIRA_MONIKER} >> $HOME/.bash_profile
	source ~/.bash_profile
fi

sudo tee <<EOF1 >/dev/null /usr/local/bin/kira_exporter.sh
#!/bin/bash

PUSHGATEWAY_ADDRESS=$PUSHGATEWAY_ADDRESS
JOB="kira"
metric_1='my_kira_top'
metric_2='my_kira_streak'
metric_3='my_kira_rank'
metric_4='my_kira_status'

function getMetrics {
temp=\$(curl -s http://localhost:11000/api/valopers | jq | grep -10 \$(curl -s http://localhost:36657/status | jq '.result.validator_info.address'))

status_temp=\$(echo \$temp | grep -E -o 'status\": \"[A-Z]*\"' | grep -E -o '[A-Z]*')

if [ "\$status_temp" = "ACTIVE" ]
then
	status=1
else
	status=0
fi

streak=\$(echo \$temp | grep -E -o 'streak\": \"[0-9]*\"' | grep -E -o '[0-9]*')
rank=\$(echo \$temp | grep -E -o 'rank\": \"[0-9]*\"' | grep -E -o '[0-9]*')
top=\$(echo \$temp | grep -E -o 'top\": \"[0-9]*\"' | grep -E -o '[0-9]*')

if [ "\$streak" = "" ]
then
	streak=0
fi

if [ "\$rank" = "" ]
then
	rank=0
fi

if [ "\$top" = "" ]
then
	top=0
fi

#LOGS
echo -e "Kira status report: status=\${status}, top=\${top}, rank=\${rank}, streak=\${streak}"

if [ "\$PUSHGATEWAY_ADDRESS" != "" ]
then
cat <<EOF | curl -s --data-binary @- $PUSHGATEWAY_ADDRESS/metrics/job/\$JOB/instance/$IP_ADDRESS
# TYPE my_kira_top gauge
\$metric_1 \$top
# TYPE my_kira_streak gauge
\$metric_2 \$streak
# TYPE my_kira_rank gauge
\$metric_3 \$rank
# TYPE my_kira_status gauge
\$metric_4 \$status
EOF
echo -e "sended to pushgataway."
fi
}

while true; do
	getMetrics
	echo "sleep 60 sec."
	sleep 60
done

EOF1

chmod +x /usr/local/bin/kira_exporter.sh

sudo tee <<EOF >/dev/null /etc/systemd/system/kira_exporter.service
[Unit]
Description=Kira Metrics Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/kira_exporter.sh

[Install]
WantedBy=multi-user.target
EOF

mkdir /etc/systemd/system/kira_exporter.service.d
sudo tee <<EOF >/dev/null /etc/systemd/system/kira_exporter.service.d/override.conf
[Service]
Environment="KIRA_MONIKER=$KIRA_MONIKER"
EOF

sudo systemctl daemon-reload && sudo systemctl enable kira_exporter && sudo systemctl start kira_exporter
 
VAR=$(systemctl is-active kira_exporter.service)

if [ "$VAR" = "active" ]
then
	echo ""
	echo -e "kira_exporter.service \e[32minstalled and works\e[39m! You can check logs by: journalctl -u kira_exporter -f"
	echo "Please note that Kira has its own metrics on ports 26660, 36660, 56660 (you can add this ports as a targets for prometheus). This exporter is just an addition to the existing ones."
	echo "Don't forget open port 9080 for promtail ($ firewall-cmd --zone=validator --permanent --add-port=9080/tcp && firewall-cmd --reload)"
	echo ""
else
	echo ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u kira_exporter -f"
	echo ""
fi
read -n 1 -s -r -p "Press any key to continue..."
}
###################################################################################
function installIronfishExporter {

if [ ! $PUSHGATEWAY_ADDRESS ] 
then
	read -p "Enter your pushgateway ip-address (example: 142.198.11.12:9091 or leave empty if you don't use pushgateway): " PUSHGATEWAY_ADDRESS
	echo 'export PUSHGATEWAY_ADDRESS='${PUSHGATEWAY_ADDRESS} >> $HOME/.bash_profile
	source ~/.bash_profile
fi

echo -e "ironfish_exporter installation starts..."
sleep 3

CV=$(systemctl list-unit-files | grep "ironfish_exporter.service")

if [ "$CV" != "" ]
then
	echo -e "Founded ironfish_exporter.service. Deleting..."
	systemctl stop ironfish_exporter && systemctl disable ironfish_exporter
	rm -rf /usr/local/bin/ironfish_exporter.sh
	rm -rf /etc/systemd/system/ironfish_exporter*
fi

sudo tee <<EOF1 >/dev/null /usr/local/bin/ironfish_exporter.sh
#!/bin/bash

PUSHGATEWAY_ADDRESS=$PUSHGATEWAY_ADDRESS
JOB="ironfish"
metric_1='my_ironfish_status'
metric_2='my_ironfish_miner_status'
metric_3='my_ironfish_peers'
metric_4='my_ironfish_blocks_height'
metric_5='my_ironfish_mined_blocks'
metric_6='my_ironfish_balance'
metric_7='my_ironfish_p2p_status'
metric_8='my_ironfish_is_synced'

function getMetrics {


temp=\$(OCLIF_TS_NODE=0 IRONFISH_DEBUG=1 ./run status)

status=\$(echo \$temp | grep -Eo 'Node(:)* [A-Z]*' | cut -d : -f2 | cut -d ' ' -f2)
if [ "\$status" = "STARTED" ]
then
	status=1
else
	status=0
fi

miner_status=\$(echo \$temp | grep -Eo 'Mining(:)* [A-Z]*' | cut -d : -f2 | cut -d ' ' -f2)
if [ "\$miner_status" = "STARTED" ]
then
	miner_status=1
else
	miner_status=0
fi

peers=\$(echo \$temp | grep -Eo 'peers [0-9]*' | grep -Eo [0-9]+)
if [ "\$peers" = "" ]
then
	peers=0
fi

blocks_height=\$(echo \$temp | grep -Eo '\([0-9]*\)' | grep -Eo [0-9]+)
if [ "\$blocks_height" = "" ]
then
	blocks_height=0
fi

mined_blocks=\$(echo \$temp | grep -Eo '[0-9]* mined' | grep -Eo [0-9]+)
if [ "\$mined_blocks" = "" ]
then
	mined_blocks=0
fi

p2p_status=\$(echo \$temp | grep -Eo 'Network(:)* [A-Z]*' | cut -d : -f2 | cut -d ' ' -f2)
if [ "\$p2p_status" = "CONNECTED" ]
then
	p2p_status=1
else
	p2p_status=0
fi

is_synced=\$(echo \$temp | grep -Eo 'Blockchain(:)* [A-Z]*' | cut -d : -f2 | cut -d ' ' -f2)
if [ "\$is_synced" = "SYNCED" ]
then
	is_synced=1
else
	is_synced=0
fi

temp=\$(OCLIF_TS_NODE=0 IRONFISH_DEBUG=1 ./run accounts:balance $IRONFISH_WALLET)

balance=\$(echo \$temp | grep -Eo 'is: \\\$IRON [0-9]+,' | grep -Eo '[0-9]+')
if [ "\$balance" = "" ]
then
	balance=0
fi

#LOGS
echo -e "Ironfish status report: node_status=\${status}, miner_status=\${miner_status}, peers=\${peers}, blocks=\${blocks_height}, mined_blocks=\${mined_blocks}, p2p_status=\${p2p_status}, balance=\${balance}, is_synced=\${is_synced}"

if [ "\$PUSHGATEWAY_ADDRESS" != "" ]
then
cat <<EOF | curl -s --data-binary @- $PUSHGATEWAY_ADDRESS/metrics/job/\$JOB/instance/$IP_ADDRESS
# TYPE my_ironfish_status gauge
\$metric_1 \$status
# TYPE my_ironfish_miner_status gauge
\$metric_2 \$miner_status
# TYPE my_ironfish_peers gauge
\$metric_3 \$peers
# TYPE my_ironfish_blocks_height gauge
\$metric_4 \$blocks_height
# TYPE my_ironfish_mined_blocks gauge
\$metric_5 \$mined_blocks
# TYPE my_ironfish_balance gauge
\$metric_6 \$balance
# TYPE my_ironfish_p2p_status gauge
\$metric_7 \$p2p_status
# TYPE my_ironfish_is_synced gauge
\$metric_8 \$is_synced
EOF
echo -e "sended to pushgataway."
fi
}

while true; do
	getMetrics
	echo "sleep 120 sec."
	sleep 120
done

EOF1

chmod +x /usr/local/bin/ironfish_exporter.sh

sudo tee <<EOF >/dev/null /etc/systemd/system/ironfish_exporter.service
[Unit]
Description=IronFish Metrics Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
WorkingDirectory=/root/ironfish/ironfish-cli/bin 
ExecStart=/usr/local/bin/ironfish_exporter.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && sudo systemctl enable ironfish_exporter && sudo systemctl start ironfish_exporter
 
VAR=$(systemctl is-active ironfish_exporter.service)

if [ "$VAR" = "active" ]
then
	echo ""
	echo -e "ironfish_exporter.service \e[32minstalled and works\e[39m! You can check logs by: journalctl -u ironfish_exporter -f"
	echo ""
else
	echo ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u ironfish_exporter -f"
	echo ""
fi
read -n 1 -s -r -p "Press any key to continue..."
}

###################################################################################
function installMinimaExporter {

if [ ! $PUSHGATEWAY_ADDRESS ] 
then
	read -p "Enter your pushgateway ip-address (example: 142.198.11.12:9091 or leave empty if you don't use pushgateway): " PUSHGATEWAY_ADDRESS
	echo 'export PUSHGATEWAY_ADDRESS='${PUSHGATEWAY_ADDRESS} >> $HOME/.bash_profile
	source ~/.bash_profile
fi

echo -e "minima_exporter installation starts..."
sleep 3

CV=$(systemctl list-unit-files | grep "minima_exporter.service")

if [ "$CV" != "" ]
then
	echo -e "Founded minima_exporter.service. Deleting..."
	systemctl stop minima_exporter && systemctl disable minima_exporter
	rm -rf /usr/local/bin/minima_exporter.sh
	rm -rf /etc/systemd/system/minima_exporter*
fi

sudo tee <<EOF1 >/dev/null /usr/local/bin/minima_exporter.sh
#!/bin/bash

PUSHGATEWAY_ADDRESS=$PUSHGATEWAY_ADDRESS
JOB="minima"
metric_1='my_minima_status'
metric_2='my_minima_lastblock'
metric_3='my_minima_connections'

function getMetrics {

temp=\$(curl -s 127.0.0.1:9002/status | jq)

status=\$(echo \$temp | grep -Eo 'status\": [a-z]*' | grep -Eo '(true|false)')
if [ "\$status" = "true" ]
then
	status=1
else
	status=0
fi

lastblock=\$(echo \$temp | grep -Eo 'lastblock\": \"[0-9]*' | grep -Eo '[0-9]*')
if [ "\$lastblock" = "" ]
then
	lastblock=0
fi

connections=\$(echo \$temp | grep -Eo 'connections\": [0-9]*' | grep -Eo '[0-9]+')
if [ "\$connections" = "" ]
then
	connections=0
fi

#LOGS
echo -e "minima status report: status=\${status}, lastblock=\${lastblock}, connections=\${connections}"

if [ "\$PUSHGATEWAY_ADDRESS" != "" ]
then
cat <<EOF | curl -s --data-binary @- $PUSHGATEWAY_ADDRESS/metrics/job/\$JOB/instance/$IP_ADDRESS
# TYPE my_minima_status gauge
\$metric_1 \$status
# TYPE my_minima_lastblock gauge
\$metric_2 \$lastblock
# TYPE my_minima_connections gauge
\$metric_3 \$connections
EOF
echo -e "sended to pushgataway."
fi
}

while true; do
	getMetrics
	echo "sleep 120 sec."
	sleep 120
done

EOF1

chmod +x /usr/local/bin/minima_exporter.sh

sudo tee <<EOF >/dev/null /etc/systemd/system/minima_exporter.service
[Unit]
Description=minima Metrics Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple 
ExecStart=/usr/local/bin/minima_exporter.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && sudo systemctl enable minima_exporter && sudo systemctl start minima_exporter
 
VAR=$(systemctl is-active minima_exporter.service)

if [ "$VAR" = "active" ]
then
	echo ""
	echo -e "minima_exporter.service \e[32minstalled and works\e[39m! You can check logs by: journalctl -u minima_exporter -f"
	echo ""
else
	echo ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u minima_exporter -f"
	echo ""
fi
read -n 1 -s -r -p "Press any key to continue..."
}
###################################################################################
function installAleoWatchdog {

echo -e "Aleo_watchdog installation starts..."
sleep 3

CV=$(systemctl list-unit-files | grep "aleo_watchdog.service")

if [ "$CV" != "" ]
then
	echo -e "Founded aleo_watchdog.service. Deleting..."
	systemctl stop aleo_watchdog && systemctl disable aleo_watchdog
	rm -rf /usr/local/bin/aleo_watchdog.sh
	rm -rf /etc/systemd/system/aleo_watchdog*
fi

sudo tee <<EOF1 >/dev/null /usr/local/bin/aleo_watchdog.sh
#!/bin/bash

BLK=0
MND=0
FAIL_COUNT=0
FAIL_LIMIT=180
SLEEP_TIME=600
AFTER_RESTART_SLEEP_TIME=7200

function waitForAleoMonitor() {
	while true; do
	VAR0=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getblockcount", "params": [] }' -H 'content-type: application/json' http://localhost:3030 | grep -E -o "result\":[0-9]*" | grep -E -o "[0-9]*")
	if [ "\$VAR0" != "" ]; then
		echo "Aleo monitoring is active!"
		break
	else
		echo "Waiting for Aleo monitoring start..."
		sleep 30
	fi
done
}

waitForAleoMonitor

function checkBlocks() {
	VAR1=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getblockcount", "params": [] }' -H 'content-type: application/json' http://localhost:3030 | grep -E -o "result\":[0-9]*" | grep -E -o "[0-9]*")
	echo \$VAR1
}

function checkSync() {
	VAR2=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getnodeinfo", "params": [] }' -H 'content-type: application/json' http://localhost:3030 | grep -E -o "is_syncing\":[A-Za-z]*" | grep -E -o "(true|false)")
	echo \$VAR2
}

function checkMining() {
	VAR3=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getnodestats", "params": [] }' -H 'content-type: application/json' http://localhost:3030 | grep -E -o "blocks_mined\":[0-9]*" | grep -E -o "[0-9]*")
	echo \$VAR3
}

function changeServices() {
	MND=0
	BLK=0
	FAIL_COUNT=0
	if [ \$(systemctl is-active aleod.service) = "active" ]; then
		systemctl stop aleod && systemctl disable aleod
		systemctl enable aleod-miner && systemctl start aleod-miner
		echo "Aleo-miner started... sleep "\$AFTER_RESTART_SLEEP_TIME" sec"
		sleep \$AFTER_RESTART_SLEEP_TIME
		waitForAleoMonitor
	elif [ \$(systemctl is-active aleod-miner.service) = "active" ]; then
		systemctl stop aleod-miner && systemctl disable aleod-miner
		systemctl enable aleod && systemctl start aleod
		echo "Aleo-node started... sleep "\$AFTER_RESTART_SLEEP_TIME" sec"
		sleep \$AFTER_RESTART_SLEEP_TIME
		waitForAleoMonitor
	fi
}

function restartAleo() {
	MND=0
	BLK=0
	FAIL_COUNT=0
	if [ \$(systemctl is-active aleod.service) = "active" ]; then
		systemctl restart aleod
		echo "Aleo-node was restarted... sleep "\$AFTER_RESTART_SLEEP_TIME" sec"
		sleep \$AFTER_RESTART_SLEEP_TIME
		waitForAleoMonitor
	elif [ \$(systemctl is-active aleod-miner.service) = "active" ]; then
		systemctl restart aleod-miner
		echo "Aleo-miner was restarted... sleep "\$AFTER_RESTART_SLEEP_TIME" sec"
		sleep \$AFTER_RESTART_SLEEP_TIME
		waitForAleoMonitor
	fi
}

while true; do
echo "--------------------------"
ACTIVE_INSTANCE=""
if [ \$(systemctl is-active aleod.service) = "active" ]; then
	ACTIVE_INSTANCE="aleod.service"
fi
if [ \$(systemctl is-active aleod-miner.service) = "active" ]; then
	ACTIVE_INSTANCE="aleod-miner.service"
fi
if [ "\$ACTIVE_INSTANCE" = "" ]; then
	echo "No ALEO MINER or NODE detected!"
	sleep 10
	continue
fi
if [ "\$ACTIVE_INSTANCE" = "aleod.service" ]; then
	if [ "\$BLK" = "0" ]; then
		BLK=\$(checkBlocks)
	fi
	echo "Active SnarkOS instance: NODE"
	echo "sleep "\$SLEEP_TIME" sec"
	sleep \$SLEEP_TIME
	BKL_TEMP=\$(checkBlocks)
	if [ "\$BLK" = "\$BKL_TEMP" ]; then
		echo "is_syncing: false. Restarting..."
		restartAleo
	else
		BLK=\$BKL_TEMP
		echo "is_syncing: true"
		IS_SYNCING=\$(checkSync)
		if [ "\$IS_SYNCING" = "false" ]; then
			echo "is_synced: true. Starting miner..."
			changeServices
		else
			echo "is_synced: false"
		fi
	fi
fi
if [ "\$ACTIVE_INSTANCE" = "aleod-miner.service" ]; then
	if [ "\$BLK" = "0" ]; then
		BLK=\$(checkBlocks)
	fi
	echo "Active SnarkOS instance: MINER"
	echo "sleep "\$SLEEP_TIME" sec"
	sleep \$SLEEP_TIME
	BKL_TEMP=\$(checkBlocks)
	if [ "\$BLK" = "\$BKL_TEMP" ]; then
		echo "is_syncing: false. Starting node..."
		changeServices
	else
		BLK=\$BKL_TEMP
		echo "is_syncing: true"
		IT_MINES=\$(checkMining)
		if [ "\$MND" = "IT_MINES" ]; then
			echo "it_miners false. FAIL_COUNT = \${FAIL_COUNT}"
			((FAIL_COUNT++))
			echo "it_miners false. FAIL_COUNT = \${FAIL_COUNT} (FAIL_LIMIT = \${FAIL_LIMIT})"
			if [ "\$FAIL_COUNT" = "\$FAIL_LIMIT" ]; then
				restartAleo
			fi
		else
			echo "it_mines: true"
			FAIL_COUNT=0
		fi
	fi
fi
done
EOF1

chmod +x /usr/local/bin/aleo_watchdog.sh

sudo tee <<EOF >/dev/null /etc/systemd/system/aleo_watchdog.service
[Unit]
Description=Aleo Watchdog
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/aleo_watchdog.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && sudo systemctl enable aleo_watchdog && sudo systemctl start aleo_watchdog
 
VAR=$(systemctl is-active aleo_watchdog.service)

if [ "$VAR" = "active" ]
then
	echo ""
	echo -e "aleo_watchdog.service \e[32minstalled and works\e[39m! You can check logs by: journalctl -u aleo_watchdog -f"
	echo ""
else
	echo ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u aleo_watchdog -f"
	echo ""
fi
read -n 1 -s -r -p "Press any key to continue..."
}

###################################################################################
function installCosmosExporter {

if [ ! $PUSHGATEWAY_ADDRESS ] 
then
	read -p "Enter your pushgateway ip-address (example: 142.198.11.12:9091 or leave empty if you don't use pushgateway): " PUSHGATEWAY_ADDRESS
	echo 'export PUSHGATEWAY_ADDRESS='${PUSHGATEWAY_ADDRESS} >> $HOME/.bash_profile
	source ~/.bash_profile
fi

echo -e "Cosmos_exporter installation starts..."
sleep 3

CV=$(systemctl list-unit-files | grep "cosmos_exporter.service")

if [ "$CV" != "" ]
then
	echo -e "Founded cosmos_exporter.service. Deleting..."
	systemctl stop cosmos_exporter && systemctl disable cosmos_exporter
	rm -rf /usr/local/bin/cosmos_exporter.sh
	rm -rf /etc/systemd/system/cosmos_exporter*
fi

sudo tee <<EOF1 >/dev/null /usr/local/bin/cosmos_exporter.sh
#!/bin/bash

PUSHGATEWAY_ADDRESS=$PUSHGATEWAY_ADDRESS
JOB="cosmos"
metric_1='my_cosmos_latest_block_height'
metric_2='my_cosmos_catching_up'
metric_3='my_cosmos_voting_power'

function getMetrics {
temp=\$(curl -s localhost:26657/status)

moniker=\$(echo \$temp | grep -Eo 'moniker\": \"[a-zA-Z0-9]*\"'| awk '{print \$2}' | cut -d/ -f1 | grep -Eo "[A-Za-z0-9]*")

if [ "\$moniker" = "" ]
then
	moniker="n/a"
fi

latest_block_height=\$(echo \$temp | grep -Eo 'latest_block_height\": \"[0-9]*\"'| awk '{print \$2}' | cut -d/ -f1 | grep -Eo [0-9]*)
if [ "\$latest_block_height" = "" ]
then
	latest_block_height=0
fi

catching_up=\$(echo \$temp | grep -Eo 'catching_up\": [a-z]*' | grep -E -o "(true|false)")
if [ "\$catching_up" = "" ]
then
	catching_up=1
fi

if [ "\$catching_up" = "true" ]
then
	catching_up=1
fi

if [ "\$catching_up" = "false" ]
then
	catching_up=0
fi

voting_power=\$(echo \$temp | grep -Eo 'voting_power\": \"[0-9]*\"'| awk '{print \$2}' | cut -d/ -f1 | grep -Eo [0-9]*)
if [ "\$voting_power" = "" ]
then
	voting_power=0
fi

#LOGS
echo -e "cosmos status report: moniker=\${moniker}, latest_block_height=\${latest_block_height}, catching_up=\${catching_up}, voting_power=\${voting_power}"

if [ "\$PUSHGATEWAY_ADDRESS" != "" ]
then
cat <<EOF | curl -s --data-binary @- $PUSHGATEWAY_ADDRESS/metrics/job/\$JOB/instance/$IP_ADDRESS
# TYPE my_cosmos_latest_block_height gauge
\$metric_1 \$latest_block_height
# TYPE my_cosmos_catching_up gauge
\$metric_2 \$catching_up
# TYPE my_cosmos_voting_power gauge
\$metric_3 \$voting_power
EOF
echo -e "sended to pushgataway."
fi
}

while true; do
	getMetrics
	echo "sleep 120 sec."
	sleep 120
done

EOF1

chmod +x /usr/local/bin/cosmos_exporter.sh

sudo tee <<EOF >/dev/null /etc/systemd/system/cosmos_exporter.service
[Unit]
Description=Cosmos exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/cosmos_exporter.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && sudo systemctl enable cosmos_exporter && sudo systemctl start cosmos_exporter
 
VAR=$(systemctl is-active cosmos_exporter.service)

if [ "$VAR" = "active" ]
then
	echo ""
	echo -e "cosmos_exporter.service \e[32minstalled and works\e[39m! You can check logs by: journalctl -u cosmos_exporter -f"
	echo ""
else
	echo ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u cosmos_exporter -f"
	echo ""
fi
read -n 1 -s -r -p "Press any key to continue..."
}
###################################################################################
function installMassaExporter {

if [ ! $PUSHGATEWAY_ADDRESS ] 
then
	read -p "Enter your pushgateway ip-address (example: 142.198.11.12:9091 or leave empty if you don't use pushgateway): " PUSHGATEWAY_ADDRESS
	echo 'export PUSHGATEWAY_ADDRESS='${PUSHGATEWAY_ADDRESS} >> $HOME/.bash_profile
	source ~/.bash_profile
fi

echo -e "massa_exporter installation starts..."
sleep 3

CV=$(systemctl list-unit-files | grep "massa_exporter.service")

if [ "$CV" != "" ]
then
	echo -e "Founded massa_exporter.service. Deleting..."
	systemctl stop massa_exporter && systemctl disable massa_exporter
	rm -rf /usr/local/bin/massa_exporter.sh
	rm -rf /etc/systemd/system/massa_exporter*
fi


sudo tee <<EOF1 >/dev/null /usr/local/bin/massa_exporter.sh
#!/bin/bash

PUSHGATEWAY_ADDRESS=$PUSHGATEWAY_ADDRESS
JOB="massa"

metric_1='my_massa_balance'
metric_2='my_massa_rolls'
metric_3='my_massa_active_rolls'
metric_4='my_massa_incoming_peers'
metric_5='my_massa_outgoing_peers'

function getMetrics {

cd $HOME/massa/massa-client/
wallet_info=\$(./massa-client --cli true wallet_info)

balance=\$(echo \$wallet_info | grep -Eo "final_ledger_data\": \{ \"balance\": \"[0-9]*.[0-9]*" |  grep -Eo "[0-9]*\.[0-9]*")
if [ "\$balance" = "" ]
then
	balance=0
fi
rolls=\$(echo \$wallet_info | grep -Eo "final_rolls\": [0-9]*"  |  grep -Eo [0-9]*)
if [ "\$rolls" = "" ]
then
	rolls=0
fi
active_rolls=\$(echo \$wallet_info | grep -Eo "active_rolls\": [0-9]*"  |  grep -Eo [0-9]*)
if [ "\$active_rolls" = "" ]
then
	active_rolls=0
fi

peers=\$(./massa-client --cli false peers)
cd

incoming_peers=\$(echo \$peers | grep -Eo 'node_id: [A-Za-z0-9]* \(incoming\)' | wc -l)
if [ "\$incoming_peers" = "" ]
then
	incoming_peers=0
fi
outgoing_peers=\$(echo \$peers | grep -Eo 'node_id: [A-Za-z0-9]* \(outgoing\)' | wc -l)
if [ "\$outgoing_peers" = "" ]
then
	outgoing_peers=0
fi

#LOGS
echo -e "massa status report: balance=\${balance}, rolls=\${rolls}, active_rolls=\${active_rolls}, incoming_peers=\${incoming_peers}, outgoing_peers=\${outgoing_peers}"

if [ "\$PUSHGATEWAY_ADDRESS" != "" ]
then
cat <<EOF | curl -s --data-binary @- $PUSHGATEWAY_ADDRESS/metrics/job/\$JOB/instance/$IP_ADDRESS
# TYPE my_massa_balance gauge
\$metric_1 \$balance
# TYPE my_massa_rolls gauge
\$metric_2 \$rolls
# TYPE my_massa_active_rolls gauge
\$metric_3 \$active_rolls
# TYPE my_massa_incoming_peers gauge
\$metric_4 \$incoming_peers
# TYPE my_massa_outgoing_peers gauge
\$metric_5 \$outgoing_peers
EOF
echo -e "sended to pushgataway."
fi
}

while true; do
	getMetrics
	echo "sleep 120 sec."
	sleep 120
done

EOF1

chmod +x /usr/local/bin/massa_exporter.sh

sudo tee <<EOF >/dev/null /etc/systemd/system/massa_exporter.service
[Unit]
Description=Massa exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/massa_exporter.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && sudo systemctl enable massa_exporter && sudo systemctl start massa_exporter
 
VAR=$(systemctl is-active massa_exporter.service)

if [ "$VAR" = "active" ]
then
	echo ""
	echo -e "massa_exporter.service \e[32minstalled and works\e[39m! You can check logs by: journalctl -u massa_exporter -f"
	echo ""
else
	echo ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u massa_exporter -f"
	echo ""
fi
read -n 1 -s -r -p "Press any key to continue..."
}
###################################################################################
function installStreamrBalance {

read -p "Enter your node's address: " NODE_ADDRESS

function getMetrics {

wallet_info=$(wget -qO- "https://testnet1.streamr.network:3013/stats/$NODE_ADDRESS")
codes_claimed=$(jq ".claimCount" <<< $wallet_info)
codes_percentage=$(jq ".claimPercentage" <<< $wallet_info)
appr_balance_DATA=`bc -l <<< "$codes_claimed*0.015"`
appr_balance_USDT=`. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/parsers/token_price.sh) -ts data -m "$appr_balance_DATA"`

#LOGS
echo -e "streamr balance: codes_claimed=\${codes_claimed}, codes_percentage=\${codes_percentage}, appr_balance_DATA=\${appr_balance_DATA}, appr_balance_USDT=\${appr_balance_USDT}"

while true; do
	getMetrics
	echo "sleep 300 sec."
	sleep 300
done

EOF1

chmod +x /usr/local/bin/streamr_balance.sh

sudo tee <<EOF >/dev/null /etc/systemd/system/streamr_balance.service
[Unit]
Description=Streamr balance checker
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/streamr_balance.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && sudo systemctl enable streamr_balance && sudo systemctl start streamr_balance
 
VAR=$(systemctl is-active streamr_balance.service)

if [ "$VAR" = "active" ]
then
	echo ""
	echo -e "streamr_balance.service \e[32minstalled and works\e[39m! You can check logs by: journalctl -u streamr_balance -f"
	echo ""
else
	echo ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u streamr_balance -f"
	echo ""
fi
read -n 1 -s -r -p "Press any key to continue..."
}

}

###################################################################################
while true; do

echo -e ""
echo -e "# MONITORING TOOLS v${VERSION}"
echo -e "# Use the script at your own risk!." 
echo -e "# Choose what to install."
echo -e " 1) Node_exporter"
echo -e " 2) Prometheus"
echo -e " 3) Grafana"
echo -e " 4) PushGateway (optional)"
echo -e " 5) Loki"
echo -e " 6) Promtail"
echo -e " 7) Aleo exporter"
echo -e " 8) Kira exporter"
echo -e " 9) IronFish exporter"
echo -e " 10) Minima exporter"
echo -e " 11) Cosmos exporter"
echo -e " 12) Massa exporter"
echo -e " 0) DELETE old custom exporters (such as nym_pg, kira_pg etc.)"   
echo -e " h) HELP"                                                                  
echo -e " x) EXIT"
echo -e ""
read option
case $option in
        1) installExporter;;
        2) installPrometheus;;
		3) installGrafana;;
        4) installPushGateway;;
		5) installLoki;;
        6) installPromtail;;
		7) installAleoExporter;;
		8) installKiraExporter;;
		9) installIronfishExporter;;
		10) installMinimaExporter;;
		11) installCosmosExporter;;
		12) installMassaExporter;;
		0) clearInstance;;
		50) installAleoWatchdog;;
		51) installStreamrBalance;;
		"h") echo -e "HELP:"
			 echo "- You need to install prometheus, grafana, loki and pushgataway (optional) for collecting metrics from your servers. It needs to be done only once and preferably on a separate server."
			 echo "- After that, go to grafana interface (ip_address:3000) and add datasource (prometeus and loki). Read here for more information: https://grafana.com/docs/grafana/latest/datasources/add-a-data-source/"
			 echo "- Add targets for prometheus (ip-addreses with ports of your node_exporters). Use sudo nano /etc/prometheus/prometheus.yml command and reboot prometheus after that. Read here for more information: https://prometheus.io/docs/prometheus/latest/getting_started/"
			 echo "- You need to install node_exporter, promtail and <blockchain_node_name>_exporter (if exists) on each server from where you want to receive metrics.";;
		"x") exit
esac
done
