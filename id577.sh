#!/bin/bash

#VERSION 0.2.1b
#VARIABLES
NODE_EXPORTER_VERSION='1.1.2'
PROMETHEUS_VERSION='2.28.0'
GRAFANA_VERSION='8.0.3'
PUSHGATEWAY_VERSION='1.4.1'
LOKI_VERSION='2.2.1'
PROMTAIL_VERSION='2.2.1'

source ~/.bash_profile
if [ ! $IP_ADDRESS ]
	then 
	IP_ADDRESS=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
	if [ "$IP_ADDRESS" =  "" ]
		then 
		read -p "IP-adress not defined. Please enter correct IP-adress: " IP_ADDRESS
	fi
	echo 'export IP_ADDRESS='${IP_ADDRESS}  >> $HOME/.bash_profile
	source ~/.bash_profile
fi

echo -e "Your IP-address is: $IP_ADDRESS"
sleep 3

###################################################################################
function clearInstance {

EXPORTERS=("kira_pg" "nym_pg" "aleo_miner_pg" "aleo_pg" "zeitgeist_pg" "rizon_pg" "ironfish_pg" "massa_pg") 
 
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
	echo -e "#########################################"
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u node_exporter -f"
	echo -e "#########################################"
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

sudo daemon-reload && sudo systemctl enable pushgateway && sudo systemctl start pushgateway
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

read -p "Enter loki IP-address and port (example: 142.198.11.12:3100): " IP_LOKI
read -p "Choose job_name: " JOB_NAME
echo -e "Promtail v${PROMTAIL_VERSION} installation starts..."
sleep 3

CV=$(systemctl list-unit-files | grep "promtail")
if [ "$CV" != "" ]
then
	systemctl stop promtail
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
if [ "\$is_synced" = "true" ]
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

temp=\$(curl -s https://testnet-rpc.kira.network/api/valopers?moniker=\$KIRA_MONIKER)
count=\$(echo $temp | wc -m)
if [ "\$count" -lt "20" ]
then
	status=0
	streak=0
	rank=0
	top=999
fi

status_temp=\$(echo \$temp | grep -E -o 'status\":\"[A-Z]*\"' | grep -E -o '[A-Z]*')

if [ "\$status_temp" = "ACTIVE" ]
then
	status=1
else
	status=0
fi

streak=\$(echo \$temp | grep -E -o 'streak\":\"[0-9]*\"' | grep -E -o '[0-9]*')
rank=\$(echo \$temp | grep -E -o 'rank\":\"[0-9]*\"' | grep -E -o '[0-9]*')
top=\$(echo \$temp | grep -E -o 'top\":\"[0-9]*\"' | grep -E -o '[0-9]*')

#LOGS
echo -e "Kira status report: status=\${status}, top=\${top}, rank=\${rank}, streak=\${streak}"

if [ "\$PUSHGATEWAY_ADDRESS" != "" ]
then
cat <<EOF | curl -s --data-binary @- $PUSHGATEWAY_ADDRESS/metrics/job/\$JOB/instance/\$IP
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
	echo "Please note that Kira has its own metrics on ports 26660, 36660, 56660. This exporter is just an addition to the existing ones."
	echo ""
else
	echo ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u kira_exporter -f"
	echo ""
fi
read -n 1 -s -r -p "Press any key to continue..."
}
###################################################################################
while true; do

echo -e ""
echo -e "# Use the script at your own risk!." 
echo -e "# Choose what to install."
echo -e " 1 - Node_exporter"
echo -e " 2 - Prometheus"
echo -e " 3 - Grafana"
echo -e " 4 - PushGateway"
echo -e " 5 - Loki"
echo -e " 6 - Promtail"
echo -e " 7 - Aleo exporter"
echo -e " 8 - Kira exporter"
echo -e " 0 - DELETE old custom exporters (such as nym_pg, kira_pg etc.)"                                                                     
echo -e " x - EXIT"
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
		0) clearInstance;;
		"x") exit
esac
done
