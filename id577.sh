#!/bin/bash

###################################################################################
function setupExporter {

CV=$(systemctl list-unit-files | grep "node_exporter.service")

if [ "$CV" != "" ]
then
	systemctl stop node_exporter
	rm -rf /etc/systemd/system/node_exporter*
fi

wget https://github.com/prometheus/node_exporter/releases/download/v1.1.2/node_exporter-1.1.2.linux-amd64.tar.gz
tar xvf node_exporter-1.1.2.linux-amd64.tar.gz
cp node_exporter-1.1.2.linux-amd64/node_exporter /usr/local/bin
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
sudo systemctl daemon-reload 
sudo systemctl enable node_exporter 
sudo systemctl start node_exporter
IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
echo "#########################################"
echo "node_exporter 1.1.2 installed successfully! Use curl -s http://$IP:9100/metrics to check Node_exporter."
echo "Dont't forget to add targets for your prometheus. Use 'sudo nano /etc/prometheus/prometheus.yml' on your server with prometheus."
echo "For additional help go to https://prometheus.io/docs/prometheus/latest/getting_started/"
echo "#########################################"
read -n 1 -s -r -p "Press any key to continue..."
}

###################################################################################
function setupPrometheusGrafana {
wget https://github.com/prometheus/prometheus/releases/download/v2.25.2/prometheus-2.25.2.linux-amd64.tar.gz
tar xfz prometheus-*.tar.gz
cd prometheus-2.25.2.linux-amd64
sudo cp ./prometheus /usr/local/bin
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
--config.file /etc/prometheus/prometheus.yml \
--storage.tsdb.path /var/lib/prometheus/ \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload 
sudo systemctl enable prometheus 
sudo systemctl start prometheus
IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
echo "#########################################"
echo "prometheus 2.25.2 installed successfully! Go to http://$IP:9090/ to check it"
echo "#########################################"
read -n 1 -s -r -p "Press any key to continue..."
sudo apt-get install -y adduser libfontconfig1
wget https://dl.grafana.com/oss/release/grafana_7.5.7_amd64.deb
sudo dpkg -i grafana_7.5.7_amd64.deb
sudo systemctl daemon-reload && sudo systemctl enable grafana-server && sudo systemctl start grafana-server
echo "#########################################"
echo "grafana 7.5.7 installed successfully! Go to http://$IP:3000/ to enter grafana"
echo "Don't forget to add data source in grafana interface. For additional help go to https://grafana.com/docs/grafana/latest/datasources/add-a-data-source/"
echo "#########################################"
read -n 1 -s -r -p "Press any key to continue..."
}

###################################################################################
function setupPushGateway {
wget https://github.com/prometheus/pushgateway/releases/download/v1.4.1/pushgateway-1.4.1.linux-amd64.tar.gz
tar xvfz pushgateway-1.4.1.linux-amd64.tar.gz
sudo cp -r ./pushgateway-1.4.1.linux-amd64/pushgateway /usr/local/bin/
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
sudo daemon-reload
sudo systemctl enable pushgateway
sudo systemctl start pushgateway
VAR=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
echo "#########################################"
echo "pushgateway 1.4.1 installed successfully!. Don't forget to add target ($VAR:9091) in your prometheus"
echo "Use 'sudo nano /etc/prometheus/prometheus.yml' on your server with prometheus"
echo "Your pushgataway address: ${VAR}:9091"
echo "#########################################"
read -n 1 -s -r -p "Press any key to continue..."
}

###################################################################################
function setupKiraExporter {

CV=$(systemctl list-unit-files | grep "kira_pg.service")

if [ "$CV" != "" ]
then
	systemctl stop kira_pg
	rm -rf /etc/systemd/system/kira_pg*
fi

echo "Enter Moniker of your node:"
read KIRA_MONIKER

sudo tee <<EOF1 >/dev/null /usr/local/bin/kira_pg.sh
#!/bin/bash

IP=\$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
JOB="kira"
METRIC1='my_kira_top'
METRIC2='my_kira_streak'
METRIC3='my_kira_rank'
METRIC4='my_kira_status'

function getMetrics {

TEMP=\$(curl -s https://testnet-rpc.kira.network/api/valopers?moniker=\$KIRA_MONIKER)
COUNT=\$(echo $TEMP | wc -m)
if [ "\$COUNT" -lt "20" ]
then
	STATUS=0
	STREAK=0
	RANK=0
	TOP=999
fi

STATUS_TEMP=\$(echo \$TEMP | grep -E -o 'status\":\"[A-Z]*\"' | grep -E -o '[A-Z]*')

if [ "\$STATUS_TEMP" = "ACTIVE" ]
then
	STATUS=1
else
	STATUS=0
fi

STREAK=\$(echo \$TEMP | grep -E -o 'streak\":\"[0-9]*\"' | grep -E -o '[0-9]*')
RANK=\$(echo \$TEMP | grep -E -o 'rank\":\"[0-9]*\"' | grep -E -o '[0-9]*')
TOP=\$(echo \$TEMP | grep -E -o 'top\":\"[0-9]*\"' | grep -E -o '[0-9]*')

#DEBUG
echo "TOP="\$TOP
echo "RANK="\$RANK
echo "STREAK="\$STREAK
echo "STATUS="\$STATUS

cat <<EOF | curl -s --data-binary @- $PUSHGATEWAY_ADDRESS/metrics/job/\$JOB/instance/\$IP
# TYPE my_kira_top gauge
\$METRIC1 \$TOP
# TYPE my_kira_streak gauge
\$METRIC2 \$STREAK
# TYPE my_kira_rank gauge
\$METRIC3 \$RANK
# TYPE my_kira_status gauge
\$METRIC4 \$STATUS
EOF

}

while true; do
	getMetrics
	echo "sleep 60 sec"
	sleep 60
done

EOF1

chmod +x /usr/local/bin/kira_pg.sh

sudo tee <<EOF >/dev/null /etc/systemd/system/kira_pg.service
[Unit]
Description=Kira Metrics Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/kira_pg.sh

[Install]
WantedBy=multi-user.target
EOF

mkdir /etc/systemd/system/kira_pg.service.d
sudo tee <<EOF >/dev/null /etc/systemd/system/kira_pg.service.d/override.conf
[Service]
Environment="KIRA_MONIKER=$KIRA_MONIKER"
EOF

sudo systemctl daemon-reload 
sudo systemctl enable kira_pg 
sudo systemctl start kira_pg

VAR=$(systemctl is-active kira_pg.service)

if [ "$VAR" = "active" ]
then
	echo "#########################################"
	echo "kira_pg.service installed successfully. You can check logs by: journalctl -u kira_pg -f"
	echo "Please note that Kira has its own metrics on ports 26660, 36660, 56660. This exporter is just an addition to the existing ones."
	echo "#########################################"
else
	echo "#########################################"
	echo "Something went wrong. Installation failed. You can check logs by: journalctl -u kira_pg -f"
	echo "#########################################"
fi
read -n 1 -s -r -p "Press any key to continue..."
}

###################################################################################
function setupNymExporter {

CV=$(systemctl list-unit-files | grep "nym_pg.service")

if [ "$CV" != "" ]
then
	systemctl stop nym_pg
	rm -rf /etc/systemd/system/nym_pg*
fi

echo "Enter Identity Key of your node:"
read NYM_PUBLIC_KEY

sudo tee <<EOF1 >/dev/null /usr/local/bin/nym_pg.sh
#!/bin/bash

IP=\$(ip addr show eth0 | grep "inet\b" | awk '{print \$2}' | cut -d/ -f1)
JOB="nym-mixnode"
METRIC1='my_nym_mixnode_isactive'
METRIC2='my_nym_mixnode_total_important_messages_count'
METRIC3='my_nym_mixnode_emergency_count'
METRIC4='my_nym_mixnode_errors_count'
METRIC5='my_nym_mixnode_warnings_count'
METRIC6='my_nym_mixnode_alerts_count'
METRIC7='my_nym_mixnode_critical_count'
METRIC8='my_nym_mixnode_notice_count'
METRIC9='my_nym_mixnode_info_count'
METRIC10='my_nym_mixnode_last5MinutesIPV4'
METRIC11='my_nym_mixnode_last5MinutesIPV6'
METRIC12='my_nym_mixnode_mixed_packets_count'

MIXED_PACKETS_COUNT=0

function getMetrics {

VAR=\$(systemctl is-active nym-mixnode.service)

if [ "\$VAR" = "active" ]
	then ISACTIVE=1
	else ISACTIVE=0
fi

EMERGENCY_COUNT=\$(journalctl -u nym-mixnode.service -p 0 --since "1 minute ago" --until "now" | grep "nym-mixnode" | wc -l)
ALERTS_COUNT=\$(journalctl -u nym-mixnode.service -p 1 --since "1 minute ago" --until "now" | grep "nym-mixnode" | wc -l)
CRITICAL_COUNT=\$(journalctl -u nym-mixnode.service -p 2 --since "1 minute ago" --until "now" | grep "nym-mixnode" | wc -l)
ERRORS_COUNT=\$(journalctl -u nym-mixnode.service -p 3 --since "1 minute ago" --until "now"| grep "nym-mixnode" | wc -l)
WARNINGS_COUNT=\$(journalctl -u nym-mixnode.service -p 4 --since "1 minute ago" --until "now"| grep "nym-mixnode" | wc -l)
NOTICE_COUNT=\$(journalctl -u nym-mixnode.service -p 5 --since "1 minute ago" --until "now"| grep "nym-mixnode" | wc -l)
INFO_COUNT=\$(journalctl -u nym-mixnode.service -p 6 --since "1 minute ago" --until "now"| grep "nym-mixnode" | wc -l)
MIXED_PACKETS_COUNT_TEMP=\$(journalctl -u nym-mixnode.service --since "1 minute ago" --until "now"| grep "nym-mixnode" | grep -E -o "mixed [0-9]*" | grep -E -o "[0-9]*") 

if [ "\$MIXED_PACKETS_COUNT_TEMP" -gt "\$MIXED_PACKETS_COUNT" ] 
then
	MIXED_PACKETS_COUNT=\$MIXED_PACKETS_COUNT_TEMP
fi 

TOTAL_IMPORTAN_MESSAGES=\$((\$EMERGENCY_COUNT+\$ALERTS_COUNT+\$CRITICAL_COUNT+\$ERRORS_COUNT+\$WARNINGS_COUNT+\$NOTICE_COUNT))

TEMP=\$(curl -s  https://testnet-finney-node-status-api.nymtech.net/api/status/mixnode/\$NYM_PUBLIC_KEY/report)
LAST5MINUTESIPV4=\$(echo \$TEMP | grep -E -o "last5MinutesIPV4\":[0-9]*" | grep -E -o ":[0-9]*" | grep -E -o [0-9]*)
LAST5MINUTESIPV6=\$(echo \$TEMP | grep -E -o "last5MinutesIPV6\":[0-9]*" | grep -E -o ":[0-9]*" | grep -E -o [0-9]*)

#DEBUG
echo "PUBLICKEY="\$NYM_PUBLIC_KEY
echo "INFO_COUNT="\$INFO_COUNT
echo "TOTAL_IMPORTAN_MESSAGES="\$TOTAL_IMPORTAN_MESSAGES
echo "LAST5MINUTESIPV4="\$LAST5MINUTESIPV4
echo "LAST5MINUTESIPV6="\$LAST5MINUTESIPV6
echo "MIXED_PACKETS_COUNT="\$MIXED_PACKETS_COUNT

cat <<EOF | curl --data-binary @- $PUSHGATEWAY_ADDRESS/metrics/job/\$JOB/instance/\$IP
# TYPE my_nym_mixnode_isactive gauge
\$METRIC1 \$ISACTIVE
# TYPE my_nym_mixnode_total_important_messages_count gauge
\$METRIC2 \$TOTAL_IMPORTAN_MESSAGES
# TYPE my_nym_mixnode_alerts_count gauge
\$METRIC6 \$ALERTS_COUNT
# TYPE my_nym_mixnode_critical_count gauge
\$METRIC7 \$CRITICAL_COUNT
# TYPE my_nym_mixnode_emergency_count gauge
\$METRIC3 \$EMERGENCY_COUNT
# TYPE my_nym_mixnode_errors_count gauge
\$METRIC4 \$ERRORS_COUNT
# TYPE my_nym_mixnode_notice_count gauge
\$METRIC8 \$NOTICE_COUNT
# TYPE my_nym_mixnode_warnings_count gauge
\$METRIC5 \$WARNINGS_COUNT
# TYPE my_nym_mixnode_info_count gauge
\$METRIC9 \$INFO_COUNT
# TYPE my_nym_mixnode_last5MinutesIPV4 gauge
\$METRIC10 \$LAST5MINUTESIPV4
# TYPE my_nym_mixnode_last5MinutesIPV6 gauge
\$METRIC11 \$LAST5MINUTESIPV6
# TYPE my_nym_mixnode_mixed_packets_count gauge
\$METRIC12 \$MIXED_PACKETS_COUNT
EOF

}

while true; do
	getMetrics
	echo "sleep 60 sec"
	sleep 60
done
EOF1

chmod +x /usr/local/bin/nym_pg.sh

sudo tee <<EOF >/dev/null /etc/systemd/system/nym_pg.service
[Unit]
Description=Nym Metrics Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/nym_pg.sh

[Install]
WantedBy=multi-user.target
EOF

mkdir /etc/systemd/system/nym_pg.service.d
sudo tee <<EOF >/dev/null /etc/systemd/system/nym_pg.service.d/override.conf
[Service]
Environment="NYM_PUBLIC_KEY=$NYM_PUBLIC_KEY"
EOF

sudo systemctl daemon-reload 
sudo systemctl enable nym_pg 
sudo systemctl start nym_pg

VAR=$(systemctl is-active nym_pg.service)

if [ "$VAR" = "active" ]
then
	echo "#########################################"
	echo "nym_pg.service installed successfully. You can check logs by: journalctl -u nym_pg -f"
	echo "#########################################"
else
	echo "#########################################"
	echo "Something went wrong. Installation failed. You can check logs by: journalctl -u nym_pg -f"
	echo "#########################################"
fi
read -n 1 -s -r -p "Press any key to continue..."
}

###################################################################################
function setupAleoMinerExporter {

CV=$(systemctl list-unit-files | grep "aleo_miner_pg.service")

if [ "$CV" != "" ]
then
	systemctl stop aleo_miner_pg
	rm -rf /etc/systemd/system/aleo_miner_pg*
fi

sudo tee <<EOF1 >/dev/null /usr/local/bin/aleo_miner_pg.sh
#!/bin/bash

IP=\$(ip addr show eth0 | grep "inet\b" | awk '{print \$2}' | cut -d/ -f1)
JOB="aleo_miner"
METRIC1='my_aleo_peers_count'
METRIC2='my_aleo_issynced'
METRIC3='my_aleo_blocks_count'
METRIC4='my_aleo_isactive'
METRIC5='my_aleo_blocks_mined_count'

function getMetrics {

PEERS_COUNT=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getpeerinfo", "params": [] }' -H 'content-type: application/json' http://localhost:3030/ | grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" | wc -l)

VAR=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getnodeinfo", "params": [] }' -H 'content-type: application/json' http://localhost:3030 | grep -E -o "is_syncing\":[A-Za-z]*" | grep -E -o "(true|false)")
if [ "\$VAR" = "true" ]
then ISSYNCED=1
else ISSYNCED=0
fi

BLOCKS_COUNT=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getblockcount", "params": [] }' -H 'content-type: application/json' http://localhost:3030 | grep -E -o "result\":[0-9]*" | grep -E -o "[0-9]*")
if [ "\$BLOCKS_COUNT" = "" ]
then BLOCKS_COUNT=0
fi

VAR2=\$(systemctl is-active aleod-miner.service)
if [ "\$VAR2" = "active" ]
then ISACTIVE=1
else ISACTIVE=0
fi

BLOCKS_MINED_COUNT=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getnodestats", "params": [] }' -H 'content-type: application/json' http://localhost:3030 | grep -E -o "blocks_mined\":[0-9]*" | grep -E -o "[0-9]*")
if [ "\$BLOCKS_MINED_COUNT" = "" ]
then BLOCKS_MINED_COUNT=0
fi

#DEBUG
echo "ISACTIVE="\$ISACTIVE
echo "ISSYNCED="\$ISSYNCED
echo "PEERS_COUNT="\$PEERS_COUNT
echo "BLOCKS_COUNT="\$BLOCKS_COUNT

cat <<EOF | curl -s --data-binary @- $PUSHGATEWAY_ADDRESS/metrics/job/\$JOB/instance/\$IP
# TYPE my_aleo_peers_count gauge
\$METRIC1 \$PEERS_COUNT
# TYPE my_aleo_issynced gauge
\$METRIC2 \$ISSYNCED
# TYPE my_aleo_blocks_count gauge
\$METRIC3 \$BLOCKS_COUNT
# TYPE my_aleo_isactive gauge
\$METRIC4 \$ISACTIVE
# TYPE my_aleo_blocks_mined_count gauge
\$METRIC5 \$BLOCKS_MINED_COUNT
EOF
}

while true; do
	getMetrics
	echo "sleep 60 sec"
	sleep 60
done

EOF1

chmod +x /usr/local/bin/aleo_miner_pg.sh

sudo tee <<EOF >/dev/null /etc/systemd/system/aleo_miner_pg.service
[Unit]
Description=Aleo Metrics Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/aleo_miner_pg.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload 
sudo systemctl enable aleo_miner_pg 
sudo systemctl start aleo_miner_pg

VAR=$(systemctl is-active aleo_miner_pg.service)

if [ "$VAR" = "active" ]
then
	echo "#########################################"
	echo "aleo_miner_pg.service installed successfully. You can check logs by: journalctl -u aleo_miner_pg -f"
	echo "#########################################"
else
	echo "#########################################"
	echo "Something went wrong. Installation failed. You can check logs by: journalctl -u aleo_miner_pg -f"
	echo "#########################################"
fi
read -n 1 -s -r -p "Press any key to continue..."
}

###################################################################################
function setupAleoNodeExporter {

CV=$(systemctl list-unit-files | grep "aleo_pg.service")

if [ "$CV" != "" ]
then
	systemctl stop aleo_pg
	rm -rf /etc/systemd/system/aleo_pg*
fi

sudo tee <<EOF1 >/dev/null /usr/local/bin/aleo_pg.sh
#!/bin/bash

IP=\$(ip addr show eth0 | grep "inet\b" | awk '{print \$2}' | cut -d/ -f1)
JOB="aleo"
METRIC1='my_aleo_peers_count'
METRIC2='my_aleo_issynced'
METRIC3='my_aleo_blocks_count'
METRIC4='my_aleo_isactive'

function getMetrics {
PEERS_COUNT=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getpeerinfo", "params": [] }' -H 'content-type: application/json' http://localhost:3030/ | grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" | wc -l)

VAR=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getnodeinfo", "params": [] }' -H 'content-type: application/json' http://localhost:3030 | grep -E -o "is_syncing\":[A-Za-z]*" | grep -E -o "(true|false)")
if [ "\$VAR" = "true" ]
then ISSYNCED=1
else ISSYNCED=0
fi

BLOCKS_COUNT=\$(curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getblockcount", "params": [] }' -H 'content-type: application/json' http://localhost:3030 | grep -E -o "result\":[0-9]*" | grep -E -o "[0-9]*")
if [ "\$BLOCKS_COUNT" = "" ]
then BLOCKS_COUNT=0
fi

VAR2=\$(systemctl is-active aleod.service)
if [ "\$VAR2" = "active" ]
then ISACTIVE=1
else ISACTIVE=0
fi

#DEBUG
echo "ISACTIVE="\$ISACTIVE
echo "ISSYNCED="\$ISSYNCED
echo "PEERS_COUNT="\$PEERS_COUNT
echo "BLOCKS_COUNT="\$BLOCKS_COUNT

cat <<EOF | curl -s --data-binary @- $PUSHGATEWAY_ADDRESS/metrics/job/\$JOB/instance/\$IP
# TYPE my_aleo_peers_count gauge
\$METRIC1 \$PEERS_COUNT
# TYPE my_aleo_issynced gauge
\$METRIC2 \$ISSYNCED
# TYPE my_aleo_blocks_count gauge
\$METRIC3 \$BLOCKS_COUNT
# TYPE my_aleo_isactive gauge
\$METRIC4 \$ISACTIVE
EOF
}

while true; do
	getMetrics
	echo "sleep 60 sec"
	sleep 60
done

EOF1

chmod +x /usr/local/bin/aleo_pg.sh

sudo tee <<EOF >/dev/null /etc/systemd/system/aleo_pg.service
[Unit]
Description=Aleo Metrics Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/aleo_pg.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload 
sudo systemctl enable aleo_pg 
sudo systemctl start aleo_pg

VAR=$(systemctl is-active aleo_pg.service)

if [ "$VAR" = "active" ]
then
	echo "#########################################"
	echo "aleo_pg.service installed successfully. You can check logs by: journalctl -u aleo_pg -f"
	echo "#########################################"
else
	echo "#########################################"
	echo "Something went wrong. Installation failed. You can check logs by: journalctl -u aleo_pg -f"
	echo "#########################################"
fi
read -n 1 -s -r -p "Press any key to continue..."
}

###################################################################################
function setupZeitgeistExporter {
CV=$(systemctl list-unit-files | grep "zeitgeist_pg.service")

if [ "$CV" != "" ]
then
	systemctl stop zeitgeist_pg
	rm -rf /etc/systemd/system/zeitgeist_pg*
fi

sudo tee <<EOF1 >/dev/null /usr/local/bin/zeitgeist_pg.sh
#!/bin/bash

IP=\$(ip addr show eth0 | grep "inet\b" | awk '{print \$2}' | cut -d/ -f1)
JOB="zeitgeist"
METRIC1='my_zeitgeist_isactive'
METRIC2='my_zeitgeist_total_important_messages_count'
METRIC3='my_zeitgeist_emergency_count'
METRIC4='my_zeitgeist_errors_count'
METRIC5='my_zeitgeist_warnings_count'
METRIC6='my_zeitgeist_alerts_count'
METRIC7='my_zeitgeist_critical_count'
METRIC8='my_zeitgeist_notice_count'
METRIC9='my_zeitgeist_peers_count'
METRIC10='my_zeitgeist_info_count'

function getMetrics {

VAR=\$(systemctl is-active zeitgeistd)

if [ "\$VAR" = "active" ]
then ISACTIVE=1
else ISACTIVE=0
fi

EMERGENCY_COUNT=\$(journalctl -u zeitgeistd -p 0 --since "1 minute ago" --until "now" | grep "zeitgeist" | wc -l)
ALERTS_COUNT=\$(journalctl -u zeitgeistd -p 1 --since "1 minute ago" --until "now" | grep "zeitgeist" | wc -l)
CRITICAL_COUNT=\$(journalctl -u zeitgeistd -p 2 --since "1 minute ago" --until "now" | grep "zeitgeist" | wc -l)
ERRORS_COUNT=\$(journalctl -u zeitgeistd -p 3 --since "1 minute ago" --until "now"| grep "zeitgeist" | wc -l)
WARNINGS_COUNT=\$(journalctl -u zeitgeistd -p 4 --since "1 minute ago" --until "now"| grep "zeitgeist" | wc -l)
NOTICE_COUNT=\$(journalctl -u zeitgeistd -p 5 --since "1 minute ago" --until "now"| grep "zeitgeist" | wc -l)
INFO_COUNT=\$(journalctl -u zeitgeistd -p 6 --since "1 minute ago" --until "now"| grep "zeitgeist" | wc -l)

TOTAL_IMPORTAN_MESSAGES=\$((\$EMERGENCY_COUNT+\$ALERTS_COUNT+\$CRITICAL_COUNT+\$ERRORS_COUNT+\$WARNINGS_COUNT+\$NOTICE_COUNT))

PEERS_COUNT=\$(journalctl -u zeitgeistd -n 2 | grep -E -o "[0-9]* peers" | grep -E -o [0-9]*)
if [ \$PEERS_COUNT = ""]
then
	PEERS_COUNT=0
fi

#DEBUG
echo "INFO_COUNT="\$INFO_COUNT
echo "TOTAL_IMPORTAN_MESSAGES="\$TOTAL_IMPORTAN_MESSAGES
echo "PEERS="\$PEERS_COUNT

cat <<EOF | curl -s --data-binary @- $PUSHGATEWAY_ADDRESS/metrics/job/\$JOB/instance/\$IP
# TYPE my_zeitgeist_isactive gauge
\$METRIC1 \$ISACTIVE
# TYPE my_zeitgeist_total_important_messages_count gauge
\$METRIC2 \$TOTAL_IMPORTAN_MESSAGES
# TYPE my_zeitgeist_peers_count gauge
\$METRIC9 \$PEERS_COUNT
# TYPE my_zeitgeist_alerts_count gauge
\$METRIC6 \$ALERTS_COUNT
# TYPE my_zeitgeist_critical_count gauge
\$METRIC7 \$CRITICAL_COUNT
# TYPE my_zeitgeist_emergency_count gauge
\$METRIC3 \$EMERGENCY_COUNT
# TYPE my_zeitgeist_errors_count gauge
\$METRIC4 \$ERRORS_COUNT
# TYPE my_zeitgeist_notice_count gauge
\$METRIC8 \$NOTICE_COUNT
# TYPE my_zeitgeist_warnings_count gauge
\$METRIC5 \$WARNINGS_COUNT
# TYPE my_zeitgeist_info_count gauge
\$METRIC10 \$INFO_COUNT
EOF
}

while true; do
	getMetrics
	echo "sleep 60 sec"
	sleep 60
done

EOF1

chmod +x /usr/local/bin/zeitgeist_pg.sh

sudo tee <<EOF >/dev/null /etc/systemd/system/zeitgeist_pg.service
[Unit]
Description=zeitgeist Metrics Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/zeitgeist_pg.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload 
sudo systemctl enable zeitgeist_pg 
sudo systemctl start zeitgeist_pg

VAR=$(systemctl is-active zeitgeist_pg.service)

if [ "$VAR" = "active" ]
then
	echo "#########################################"
	echo "zeitgeist_pg.service installed successfully. You can check logs by: journalctl -u zeitgeist_pg -f"
	echo "#########################################"
else
	echo "#########################################"
	echo "Something went wrong. Installation failed. You can check logs by: journalctl -u zeitgeist_pg -f"
	echo "#########################################"
fi
read -n 1 -s -r -p "Press any key to continue..."
}

while true; do

echo "#########################################"
echo "I made this script for myself and I do not give any guarantees of performance (tested on Contabo servers). Use the script at your own risk."
echo "Attention. Some exporters is only for nodes installed using nodes.guru guides (but of course you can edit it for yourself)"
echo "Choose what to install. For help type '99'."
echo "1 - Node_exporter"
echo "2 - Prometheus + Grafana"
echo "3 - Prometheus + Grafana + PushGateway + Node_exporter"
echo "4 - Kira_exporter + Node_exporter"
echo "5 - Nym_exporter (NodesGuru) + Node_exporter"
echo "6 - Aleo_Miner_exporter (NodesGuru) + Node_exporter"
echo "7 - Aleo_Node_exporter (NodesGuru) + Node_exporter"
echo "8 - Zeitgeist_exporter (NodesGuru) + Node_exporter"
echo "99 - HELP"
echo "999 - EXIT"
echo "#########################################"
read option
case $option in
        1) setupExporter;;
        2) setupPrometheusGrafana;;
        3) setupExporter
           setupPrometheusGrafana
		   setupPushGateway;;
		4) setupKiraExporter
		   setupExporter
		   sudo firewall-cmd --zone=validator --permanent --add-port=9100/tcp
		   sudo firewall-cmd --reload;;
        5) echo "Enter your pushgateway ip-address and port (example: 144.145.32.32:9091):"
		   read PUSHGATEWAY_ADDRESS
		   setupNymExporter
		   setupExporter;;
		6) echo "Enter your pushgateway ip-address and port (example: 144.145.32.32:9091):"
		   read PUSHGATEWAY_ADDRESS
		   setupAleoMinerExporter
		   setupExporter;;
		7) echo "Enter your pushgateway ip-address and port (example: 144.145.32.32:9091):"
		   read PUSHGATEWAY_ADDRESS
		   setupAleoNodeExporter
		   setupExporter;;
		8) echo "Enter your pushgateway ip-address and port (example: 144.145.32.32:9091):"
		   read PUSHGATEWAY_ADDRESS
		   setupZeitgeistExporter
		   setupExporter;;
		99) echo "#########################################"
			echo "You need to install prometheus, grafana and pushgateway for collecting metrics from your servers/nodes."
			echo "This needs to be done only once and preferably on a separate server."
			echo "On each server with a node, you need to install node_exporter (for collecting linux metrics) and special exporter for the node (for example, if kira node is installed on your server, you need to install kira_exporter - to collect metrics from the node; node_exporter - to collect Linux metrics"
			echo "After installation you need to add targets for prometheus and data source for grafana"
			echo "For additional help go to:"
			echo "https://grafana.com/docs/grafana/latest/datasources/add-a-data-source/"
			echo "https://prometheus.io/docs/prometheus/latest/getting_started/"
			echo "Metrics from nodes have the construction: my_<node_name>_..."
			echo "#########################################"
			read -n 1 -s -r -p "Press any key to continue...";;
		999) exit
esac
done


