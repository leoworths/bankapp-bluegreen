# Update system and install wget
sudo apt-get update
sudo apt-get install -y wget




# Install Node Exporter on application server 
wget https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz
tar -xvf node_exporter-1.9.1.linux-amd64.tar.gz
rm node_exporter-1.9.1.linux-amd64.tar.gz
mv node_exporter-1.9.1.linux-amd64/ node_exporter
cd node_exporter
#start Node Exporter
./node_exporter &



# Install Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v3.4.1/prometheus-3.4.1.linux-amd64.tar.gz
tar -xvf prometheus-3.4.1.linux-amd64.tar.gz
rm prometheus-3.4.1.linux-amd64.tar.gz
mv prometheus-3.4.1.linux-amd64/ prometheus
cd prometheus
#start Prometheus
./prometheus &


# Copy Prometheus configuration files
sudo cp -r consoles/ console_libraries/ /etc/prometheus/
sudo cp prometheus.yml /etc/prometheus/prometheus.yml

# Start Prometheus
./prometheus --config.file=/etc/prometheus/prometheus.yml &

# Install Blackbox Exporter
cd ..
wget https://github.com/prometheus/blackbox_exporter/releases/download/v0.26.0/blackbox_exporter-0.26.0.linux-amd64.tar.gz
tar -xvf blackbox_exporter-0.26.0.linux-amd64.tar.gz
rm blackbox_exporter-0.26.0.linux-amd64.tar.gz
mv blackbox_exporter-0.26.0.linux-amd64/ blackbox_exporter
cd blackbox_exporter
#start Blackbox Exporter
./blackbox_exporter &


# Install Alertmanager
cd ..
wget https://github.com/prometheus/alertmanager/releases/download/v0.28.1/alertmanager-0.28.1.linux-amd64.tar.gz
tar -xvf alertmanager-0.28.1.linux-amd64.tar.gz
rm alertmanager-0.28.1.linux-amd64.tar.gz
mv alertmanager-0.28.1.linux-amd64/ alertmanager
cd alertmanager
# Copy Alertmanager configuration
sudo cp /etc/prometheus/alertmanager.yml /etc/prometheus/alertmanager.yml

# Start Alertmanager
pgrep alertmanager | xargs kill -9
./alertmanager --config.file=/etc/prometheus/alertmanager.yml &

# Install Grafana
sudo apt-get install -y adduser libfontconfig1 musl
wget https://dl.grafana.com/enterprise/release/grafana-enterprise_11.5.2_amd64.deb
sudo dpkg -i grafana-enterprise_11.5.2_amd64.deb
sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

# Restart Prometheus if necessary
pgrep prometheus | xargs kill -9
./prometheus --config.file=/etc/prometheus/prometheus.yml &

