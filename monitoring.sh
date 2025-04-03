# Update system and install wget
sudo apt-get update
sudo apt-get install -y wget

# Install Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v3.2.1/prometheus-3.2.1.linux-amd64.tar.gz
tar -xvf prometheus-3.2.1.linux-amd64.tar.gz
rm prometheus-3.2.1.linux-amd64.tar.gz
mv prometheus-3.2.1.linux-amd64/ prometheus
cd prometheus

# Copy Prometheus binaries and configuration files
sudo cp prometheus /usr/local/bin/
sudo cp promtool /usr/local/bin/
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

# Copy Blackbox Exporter binary and config
sudo cp blackbox_exporter /usr/local/bin/
sudo cp /etc/prometheus/blackbox.yml /etc/prometheus/blackbox.yml

# Start Blackbox Exporter
./blackbox_exporter --config.file=/etc/prometheus/blackbox.yml &

# Install Node Exporter
cd ..
wget https://github.com/prometheus/node_exporter/releases/download/v1.9.0/node_exporter-1.9.0.linux-amd64.tar.gz
tar -xvf node_exporter-1.9.0.linux-amd64.tar.gz
rm node_exporter-1.9.0.linux-amd64.tar.gz
mv node_exporter-1.9.0.linux-amd64/ node_exporter
cd node_exporter

# Copy Node Exporter binary and start it
sudo cp node_exporter /usr/local/bin/
./node_exporter &

# Install Alertmanager
cd ..
wget https://github.com/prometheus/alertmanager/releases/download/v0.28.1/alertmanager-0.28.1.linux-amd64.tar.gz
tar -xvf alertmanager-0.28.1.linux-amd64.tar.gz
rm alertmanager-0.28.1.linux-amd64.tar.gz
mv alertmanager-0.28.1.linux-amd64/ alertmanager
cd alertmanager

# Copy Alertmanager binary and configuration
sudo cp alertmanager /usr/local/bin/
sudo cp /etc/prometheus/alertmanager.yml /etc/prometheus/alertmanager.yml

# Start Alertmanager
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
