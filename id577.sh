#!/bin/bash

#VARIABLES
VERSION='0.3.2'
NODE_EXPORTER_VERSION='1.4.0'
PROMETHEUS_VERSION='2.37.1'
GRAFANA_VERSION='9.2.0~beta1'
PUSHGATEWAY_VERSION='1.4.1'
LOKI_VERSION='2.6.1'
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
fi
source $HOME/.bash_profile
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
User=$USER
Group=$USER
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
	echo -e "node_exporter v$NODE_EXPORTER_VERSION \e[32minstalled and works\e[39m! Use curl -s http://$IP_ADDRESS:9100/metrics to check Node_exporter."
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
User=$USER
Group=$USER
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
sleep 3

VAR=$(systemctl is-active grafana-server.service)
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
User=$USER
Group=$USER
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
User=$USER
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
source $HOME/.bash_profile
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
User=$USER
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
	if [ "$PUSHGATEWAY_ADDRESS" != "" ] 
	then
		echo 'export PUSHGATEWAY_ADDRESS='${PUSHGATEWAY_ADDRESS} >> $HOME/.bash_profile
	fi
fi
echo -e "Aleo_exporter installation starts..."
sleep 3

CV=$(systemctl list-unit-files | grep "aleo_exporter.service")
if [ "$CV" != "" ]
then
	echo -e "Founded aleo_exporter.service. Deleting..."
	systemctl stop aleo_exporter && systemctl disable aleo_exporter
	rm -rf /usr/local/bin/aleo_exporter.sh
	rm -rf /etc/systemd/system/aleo_exporter*
fi

source $HOME/.bash_profile

sudo tee <<EOF1 >/dev/null /usr/local/bin/aleo_exporter.sh
#!/bin/bash

PUSHGATEWAY_ADDRESS=$PUSHGATEWAY_ADDRESS
job="aleo"
node="localhost:3032"
metric_1='my_aleo_peers_count'
metric_2='my_aleo_blocks_count'

function getMetrics {

status=

peers_count=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getconnectedpeers", "params": [] }' -H 'content-type: application/json' http://\$node/ | jq '.result[]' | wc -l)
if [ "\$peers_count" = "" ]
then peers_count=0
fi

blocks_count=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "latestblockheight", "params": [] }' -H 'content-type: application/json' http://\$node/ | jq '.result')
if [ "\$blocks_count" = "" ]
then blocks_count=0
fi

status=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getnodestate", "params": [] }' -H 'content-type: application/json' http://\$node/ | jq '.result' | grep -Eo "status\": \"[A-Za-z]*" | awk '{print \$2}' | grep -Eo "[A-Za-z]*")

if [ "\$status" = "Syncing" ]; then
	status=1
elif [ "\$status" = "Peering" ]; then
	status=2
elif [ "\$status" = "Mining" ]; then
	status=3
else
	status=0
fi

#LOGS
echo -e "Aleo status report: status=\${status}, peers_count=\${peers_count}, blocks_count=\${blocks_count}, blocks_mined_count=n/a"

if [ "\$PUSHGATEWAY_ADDRESS" != "" ]
then
cat <<EOF | curl -s --data-binary @- \$PUSHGATEWAY_ADDRESS/metrics/job/\$job/instance/$IP_ADDRESS
# TYPE my_aleo_peers_count gauge
\$metric_1 \$peers_count
# TYPE my_aleo_blocks_count gauge
\$metric_2 \$blocks_count
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
User=$USER
Group=$USER
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
	if [ "$PUSHGATEWAY_ADDRESS" != "" ] 
	then
		echo 'export PUSHGATEWAY_ADDRESS='${PUSHGATEWAY_ADDRESS} >> $HOME/.bash_profile
	fi
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
source $HOME/.bash_profile

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
User=$USER
Group=$USER
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

source $HOME/.bash_profile
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
cd /usr/bin
echo -e "Defining a default wallet..."
DEFAULT_WALLET=$(OCLIF_TS_NODE=0 IRONFISH_DEBUG=1 ./ironfish accounts:which)
if [ "$DEFAULT_WALLET" != "" ]; then
	echo -e "Success! Default wallet is ${DEFAULT_WALLET}"
else
	echo -e "Failed to determine default wallet!"
	read -p "Enter your default wallet name: " DEFAULT_WALLET
fi

sudo tee <<EOF1 >/dev/null /usr/local/bin/ironfish_exporter.sh
#!/bin/bash

function getMetrics {

temp=\$(OCLIF_TS_NODE=0 IRONFISH_DEBUG=1 ./ironfish status)

status=\$(echo \$temp | grep -Eo 'Node(:)* [A-Z]* ' | cut -d : -f2 | cut -d ' ' -f2)
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

is_synced=\$(echo \$temp | grep -Eo '[0-9]+m [0-9]+s \([A-Z]*\)'| cut -d ' ' -f3 | grep -Eo '[A-Z]+')
if [ "\$is_synced" = "SYNCED" ]
then
	is_synced=1
else
	is_synced=0
fi

version=\$(echo \$temp | grep -Eo 'Version(:)* [0-9]*.[0-9]*.[0-9]*' | cut -d ' ' -f2)
node_name=\$(echo \$temp | grep -Eo 'Node Name(:)* [0-9A-Za-z]*' | cut -d ' ' -f3)
graffiti=\$(echo \$temp | grep -Eo 'Graffiti(:)* [0-9A-Za-z]*' | cut -d ' ' -f2)

temp=\$(OCLIF_TS_NODE=0 IRONFISH_DEBUG=1 ./ironfish accounts:balance $DEFAULT_WALLET)

balance=\$(echo \$temp | grep -Eo "IRON [0-9]+.[0-9]+" |  grep -Eo "[0-9]+.[0-9]+")
if [ "\$balance" = "" ]
then
	balance=0
fi

#LOGS
echo -e "ironfish node info: node_name=\${node_name}, block_graffiti=\${graffiti}, version=\${version}"
echo -e "Ironfish status report: node_status=\${status}, miner_status=\${miner_status}, peers=\${peers}, blocks=\${blocks_height}, mined_blocks=\${mined_blocks}, p2p_status=\${p2p_status}, balance=\${balance}, is_synced=\${is_synced}"

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
User=$USER
Group=$USER
Type=simple
WorkingDirectory=/usr/bin 
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
	if [ "$PUSHGATEWAY_ADDRESS" != "" ] 
	then
		echo 'export PUSHGATEWAY_ADDRESS='${PUSHGATEWAY_ADDRESS} >> $HOME/.bash_profile
	fi
fi
source $HOME/.bash_profile
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

temp=\$(curl -s 127.0.0.1:9002/status)

lastblock=\$(echo \$temp | jq .response.chain.block)
connections=\$(echo \$temp | jq .response.network.connected)
version=\$(echo \$temp | jq .response.version | sed 's/"//g') 
total_devices=\$(echo \$temp | jq .response.devices)
status=\$(echo \$temp | jq .status)

if [ "\$lastblock" = "" ]
then lastblock=0
elif [ "\$connections" = "" ]
then connections=0
elif [ "\$status" = "true" ]
then status=1
else status=0
fi

temp=\$(curl -s 127.0.0.1:9002/incentivecash)

incentivecash_status=\$(echo \$temp | jq .status)
daily_rewards=\$(echo \$temp | jq .response.details.rewards.dailyRewards)

if [ "\$incentivecash_status" = "true" ]
then incentivecash_status=1
else incentivecash_status=0
fi

#LOGS
echo -e "minima node info: version=\${version}, total_devices=\${total_devices}"
echo -e "minima status report: status=\${status}, lastblock=\${lastblock}, connections=\${connections}, incentivecash_status=\${incentivecash_status}, daily_rewards=\${daily_rewards}"

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
User=$USER
Group=$USER
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
function installCosmosExporter {
SUPPORTER_NODES="Althea, Evmos, Idep, Stratos, Umee, assetMantle"
echo -e "The script supports only one cosmos node per instance. At least for now!"
read -n 1 -s -r -p "Press any key to continue or CRTL+C for abort installation..."
echo ""
if [ ! $PUSHGATEWAY_ADDRESS ] 
then
	read -p "Enter your pushgateway ip-address (example: 142.198.11.12:9091 or leave empty if you don't use pushgateway): " PUSHGATEWAY_ADDRESS
	if [ "$PUSHGATEWAY_ADDRESS" != "" ] 
	then
		echo 'export PUSHGATEWAY_ADDRESS='${PUSHGATEWAY_ADDRESS} >> $HOME/.bash_profile
	fi
fi
if [ ! $DAEMON ]
then	
	COSMOS_NODES=("evmosd" "iond" "althead" "stratosd" "umeed" "assetd") 
	for item in ${COSMOS_NODES[*]}
	do
	if [  -f "/etc/systemd/system/${item}.service" ]
		then
			echo -e "${item} founded!"
			DAEMON="${item}"
			case $DAEMON in    
				"idepd") DAEMON="iond";;
				"althead") DAEMON="althea";;
				"stratosd") DAEMON="stchaincli";;
				"assetd") DAEMON="assetClient"
			esac
			break
	fi
	done
fi

if [ ! $DAEMON ]
	then
		echo -e "No supported cosmos node founded! Not all spript functions will be active"
		echo "Supported cosmos nodes: ${SUPPORTER_NODES}"
	else
		echo 'export DAEMON='${DAEMON} >> $HOME/.bash_profile
fi
sleep 3
source $HOME/.bash_profile
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
DAEMON=$DAEMON
metric_1='my_cosmos_latest_block_height'
metric_2='my_cosmos_catching_up'
metric_3='my_cosmos_voting_power'
metric_4='my_cosmos_jailed'

function getMetrics {
temp=\$(curl -s localhost:26657/status)

moniker=\$(echo \$temp | jq .result.node_info.moniker | sed 's/"//g')
latest_block_height=\$(echo \$temp | jq .result.sync_info.latest_block_height | sed 's/"//g')
catching_up=\$(echo \$temp | jq .result.sync_info.catching_up | sed 's/"//g')
voting_power=\$(echo \$temp | jq .result.validator_info.voting_power | sed 's/"//g')
if [ "\$moniker" = "" ]
then
	moniker="n/a"
elif [ "\$latest_block_height" = "" ]
then
	latest_block_height=0
elif [ "\$catching_up" = "" ] || [ "\$catching_up" = "true" ]
then
	catching_up=1
else 
	catching_up=0
fi
if [ "\$voting_power" = "" ]
then
	voting_power=0
fi

if [ "\$DAEMON" != "" ]
then
	case \$DAEMON in  
		"iond" | "althea" | "evmosd" | "umeed") jailed=\$($(which ${DAEMON}) query staking validators --limit 10000 --output json | jq -r '.validators[] | select(.description.moniker=='\"\$moniker\"')' | jq -r '.jailed');;
		"stchaincli") jailed=\$(stchaincli query staking validator \$(stchaincli keys show \$moniker --bech val --address --keyring-backend test) --trust-node --node \$(cat "$HOME/.stchaind/config/config.toml" | grep -oPm1 "(?<=^laddr = \")([^%]+)(?=\")") | grep -Eo "jailed: (true|false)" | grep -Eo "(true|false)");;
		"assetClient") jailed=\$(\$(which assetClient) q staking validators --output json | jq -r '.[] | select(.description.moniker=="\$moniker")' | jq -r '.jailed')
	esac
	if [ "\$jailed" = "" ] || [ "\$jailed" = "true" ]
	then
		jailed=1
	else
		jailed=0
	fi
else
	jailed="n/a"
fi

#LOGS
echo -e "cosmos status report: moniker=\${moniker}, latest_block_height=\${latest_block_height}, catching_up=\${catching_up}, voting_power=\${voting_power}, jailed=\${jailed}"

if [ "\$PUSHGATEWAY_ADDRESS" != "" ] && [ "\$DAEMON" != "" ]
then
cat <<EOF | curl -s --data-binary @- $PUSHGATEWAY_ADDRESS/metrics/job/\$JOB/instance/$IP_ADDRESS
# TYPE my_cosmos_latest_block_height gauge
\$metric_1 \$latest_block_height
# TYPE my_cosmos_catching_up gauge
\$metric_2 \$catching_up
# TYPE my_cosmos_voting_power gauge
\$metric_3 \$voting_power
# TYPE my_cosmos_jailed gauge
\$metric_3 \$jailed
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
User=$USER
Group=$USER
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
	if [ "$PUSHGATEWAY_ADDRESS" != "" ] 
	then
		echo 'export PUSHGATEWAY_ADDRESS='${PUSHGATEWAY_ADDRESS} >> $HOME/.bash_profile
	fi
fi
read -p "Enter your wallet password: " MASSA_PASSWORD
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
source $HOME/.bash_profile

sudo tee <<EOF1 >/dev/null /usr/local/bin/massa_exporter.sh
#!/bin/bash

PUSHGATEWAY_ADDRESS=$PUSHGATEWAY_ADDRESS
MASSA_PASSWORD=$MASSA_PASSWORD
JOB="massa"
metric_1='my_massa_balance'
metric_2='my_massa_rolls'
metric_3='my_massa_active_rolls'
metric_4='my_massa_incoming_peers'
metric_5='my_massa_outgoing_peers'

function getMetrics {

cd $HOME/massa/massa-client/
wallet_info=\$(./massa-client wallet_info -p \$MASSA_PASSWORD)
balance=\$(echo \$wallet_info | grep -Eo "Balance: final=[0-9]+[\.]{0,1}[0-9]*" |  grep -Eo "[0-9]+[\.]{0,1}[0-9]*")
rolls=\$(echo \$wallet_info | grep -Eo "Rolls: active=[0-9]+, final=[0-9]+" | grep -Eo "final=[0-9]+" | grep -Eo "[0-9]+")
active_rolls=\$(echo \$wallet_info |  grep -Eo "Rolls: active=[0-9]+" |  grep -Eo "[0-9]+")

status=\$(./massa-client get_status -p \$MASSA_PASSWORD)
incoming_peers=\$(echo \$status | grep -Eo "In connections: [0-9]+*" | grep -Eo "[0-9]+")
outgoing_peers=\$(echo \$status | grep -Eo "Out connections: [0-9]+*" | grep -Eo "[0-9]+")
current_cycle=\$(echo \$status | grep -Eo "Current cycle: [0-9]+*" | grep -Eo "[0-9]+")
node_id=\$(echo \$status | grep -Eo "Node's ID: \w{50}" | grep -Eo -m 1 "\w{50}" )
node_version=\$(echo \$status | grep -Eo "Version: TEST.[0-9]+.[0-9]+" | sed 's/V/v/g' | sed 's/: TEST./=/g')
cd

if [ "\$balance" = "" ]
then
	balance=0
elif [ "\$rolls" = "" ]
then
	rolls=0
elif [ "\$active_rolls" = "" ]
then
	active_rolls=0
elif [ "\$incoming_peers" = "" ]
then
	incoming_peers=0
elif [ "\$outgoing_peers" = "" ]
then
	outgoing_peers=0
elif [ "\$current_cycle" = "" ]
then
	current_cycle=0 
elif [ "\$staker_count" = "" ]
then
	staker_count=0 
elif [ "\$node_id" = "" ]
then
	node_id="n/a"
elif [ "\$node_version" = "" ]
then
	node_version="n/a"
fi

#LOGS
echo -e "massa node info: node_id=\${node_id}, \${node_version}"
echo -e "massa status report: balance=\${balance}, rolls=\${rolls}, active_rolls=\${active_rolls}, incoming_peers=\${incoming_peers}, outgoing_peers=\${outgoing_peers}, current_cycle=\${current_cycle}"

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
User=$USER
Group=$USER
Type=simple
ExecStart=/usr/local/bin/massa_exporter.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && sudo systemctl enable massa_exporter && sudo systemctl restart massa_exporter
 
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

if [ ! $streamr_wallet_address ] 
then
	read -p "Enter your node's address: " streamr_wallet_address
	echo 'export streamr_wallet_address='${streamr_wallet_address}  >> $HOME/.bash_profile
fi

sudo apt install bc

sudo tee <<EOF1 >/dev/null /usr/local/bin/streamr_balance.sh
#!/bin/bash
function getMetrics {

wallet_info=\$(wget -qO- "https://testnet1.streamr.network:3013/stats/$streamr_wallet_address")
codes_claimed=\$(jq ".claimCount" <<< \$wallet_info)
if [ "\$codes_claimed" = "" ]
then
	codes_claimed=0
fi

#LOGS
echo -e "streamr balance: codes_claimed=\${codes_claimed}"
}

while true; do
	getMetrics
	echo "sleep 120 sec."
	sleep 300
done
EOF1

chmod +x /usr/local/bin/streamr_balance.sh

sudo tee <<EOF >/dev/null /etc/systemd/system/streamr_balance.service
[Unit]
Description=Streamr Balance Checker
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
Group=$USER
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

###################################################################################
function installUmeeAD {

echo -e "UmeeAD installation starts..."
sleep 3
read -p "Enter your umee wallet address: " UMEE_WALLET
read -p "Enter your wallet password: " UUMEE_WALLET_PASSWORD
read -p "Enter your validator address: " UMEE_VALOPER
read -p "Enter chain-id: " UMEE_CHAIN
read -p "Enter delay: (default 6 hours)" DELAY_TIME
DELAY_TIME=${DELAY_TIME:-60}

CV=$(systemctl list-unit-files | grep "umee_ad")
if [ "$CV" != "" ]
then
	systemctl stop umee_ad
fi

sudo tee <<EOF1 >/dev/null /usr/local/bin/umee_ad.sh
#!/bin/bash

UMEE_WALLET=$UMEE_WALLET
UMEE_WALLET_PASSWORD=$UUMEE_WALLET_PASSWORD
UMEE_VALOPER=$UMEE_VALOPER
UMEE_CHAIN=$UMEE_CHAIN
DELAY_TIME=$DELAY_TIME
MIN_AMOUNT_FOR_DELEGATION=1
FEES=300

MSG=1

while true; do
	START_AMOUNT=\$($(which umeed) q bank balances \$UMEE_WALLET -o json | grep -Eo "uumee\\",\\"amount\\":\\"[0-9]*" | grep -Eo "[0-9]*")
	sleep 10
	
	while [ \$MSG -ne 0 ]; do
		echo -e "\${UMEE_WALLET_PASSWORD}\\n" | $(which umeed) tx distribution withdraw-all-rewards --from=\$UMEE_WALLET --chain-id=\$UMEE_CHAIN --fees=\${FEES}uumee -y &>> cosmos_ad_logs.txt
		MSG=\$?
		if [ \$MSG -eq 0 ]; then
			echo -e "Successfully withdraw-all-rewards!"
		else
			echo -e "Failed to withdraw-all-rewards. Retry in 10 sec..."
		fi
		sleep 10
	done
	
	MSG=1
	
	while [ \$MSG -ne 0 ]; do
		echo -e "\${UMEE_WALLET_PASSWORD}\\n" | $(which umeed) tx distribution withdraw-rewards \$UMEE_VALOPER --from=\$UMEE_WALLET --chain-id=\$UMEE_CHAIN --fees=\${FEES}uumee --commission -y &>> cosmos_ad_logs.txt
		MSG=\$?
		if [ \$MSG -eq 0 ]; then
			echo -e "Successfully withdraw rewards from commission!"
		else
			echo -e "Failed to withdraw rewards from commission. Retry in 10 sec..."
		fi
		sleep 10
	done
	
	MSG=1
	
	END_AMOUNT=\$($(which umeed) q bank balances \$UMEE_WALLET -o json | grep -Eo "uumee\\",\\"amount\\":\\"[0-9]*" | grep -Eo "[0-9]*")
	END_AMOUNT=\$(( \$END_AMOUNT - \$START_AMOUNT ))
	echo -e "Total \${END_AMOUNT} uumee has been withdrawn"
	END_AMOUNT=\$(( \$END_AMOUNT - \$FEES ))
	
	while [ \$MSG -ne 0 ]; do
		if [ \$END_AMOUNT -lt \$MIN_AMOUNT_FOR_DELEGATION ]; then
			echo "Too low balance for delegation. Skip..."
			break
		fi
		echo -e "\${UMEE_WALLET_PASSWORD}\\n" | $(which umeed) tx staking delegate \$UMEE_VALOPER \${END_AMOUNT}uumee --from=\$UMEE_WALLET --chain-id=\$UMEE_CHAIN --fees=\${FEES}uumee -y &>> cosmos_ad_logs.txt
		MSG=\$?
		if [ \$MSG -eq 0 ]; then
			echo -e "Successfully delegated \$END_AMOUNT uumee!"
		else
			echo -e "Failed to delegate. Retry in 10 sec..."
		fi
		sleep 10
	done
	
	MSG=1
	
	echo "Sleep \${DELAY_TIME} sec"
	sleep \$DELAY_TIME
done

EOF1

chmod +x /usr/local/bin/umee_ad.sh

sudo tee <<EOF >/dev/null /etc/systemd/system/umee_ad.service
[Unit]
Description=umee Auto-Delegation
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
Group=$USER
Type=simple
ExecStart=/usr/local/bin/umee_ad.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && sudo systemctl enable umee_ad && sudo systemctl start umee_ad
 
VAR=$(systemctl is-active umee_ad.service)

if [ "$VAR" = "active" ]
then
	echo ""
	echo -e "umee_ad.service \e[32minstalled and works\e[39m! You can check logs by: journalctl -u umee_ad -f"
	echo ""
else
	echo ""
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u umee_ad -f"
	echo ""
fi
read -n 1 -s -r -p "Press any key to continue..."
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
echo -e " 13) Umee Auto-Delegation"
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
		13) installUmeeAD;;
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
