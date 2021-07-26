#!/bin/bash

#VERSION 0.2.0b
#VARIABLES
NODE_EXPORTER_VERSION='1.1.2'
PROMETHEUS_VERSION='2.28.0'
GRAFANA_VERSION='8.0.3'
PUSHGATEWAY_VERSION='1.4.1'
LOKI_VERSION='2.2.1'
PROMTAIL_VERSION='2.2.1'

IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

if [ "$IP" == "" ]
	then 
		read -p "IP-adress not defined. Please enter correct IP-adress: " IP
fi

echo -e "Your IP-address is: $IP"

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
	echo -e "node_exporter v$NODE_EXPORTER_VERSION \e[32minstalled and works\e[39m    ! Use curl -s http://$IP:9100/metrics to check Node_exporter."
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
sleep 3

VAR=$(systemctl is-active prometheus.service)
if [ "$VAR" = "active" ]
then
	echo -e ""
	echo -e "Prometheus v$PROMETHEUS_VERSION \e[32minstalled and works\e[39m! Go to http://$IP:9090/ to check it"
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

VAR=$(systemctl is-active grafana.service)
if [ "$VAR" = "active" ]
then
	echo -e ""
	echo -e "Grafana v$GRAFANA_VERSION \e[32minstalled and works\e[39m! Go to http://$IP:3000/ to enter grafana"
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
	echo -e "Pushgateway 1.4.1 \e[32minstalled and works\e[39m!. Go to http://$IP:9091 to check it."
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
sleep 3

VAR=$(systemctl is-active loki.service)
if [ "$VAR" = "active" ]
then
	echo -e ""
	echo -e "#########################################"
	echo -e "loki v${LOKI_VERSION} \e[32minstalled and works\e[39m! You can check logs by: journalctl -u loki -f"
	echo -e "Don't forget to add data source (loki) in grafana interface."
	echo -e "#########################################"
	echo -e ""
else
	echo -e ""
	echo -e "#########################################"
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u loki -f"
	echo -e "#########################################"
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
        host: $IP
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
	echo -e "#########################################"
	echo -e "Promtail v${PROMTAIL_VERSION} \e[32minstalled and works\e[39m    . You can check logs by: journalctl -u promtail -f"
	echo -e "#########################################"
	echo -e ""
else
	echo -e ""
	echo -e "#########################################"
	echo -e "Something went wrong. \e[31mInstallation failed\e[39m! You can check logs by: journalctl -u promtail -f"
	echo -e "#########################################"
	echo -e ""
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
echo -e " 0 - DELETE custom exporters (nym_pg, kira_pg etc.)"                                                                     
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
		0) clearInstance;;
		"x") exit
esac
done


