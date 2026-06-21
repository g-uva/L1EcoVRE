#!/bin/bash
mkdir -p /home/jovyan/.bin /home/jovyan/.local/bin
export PATH=/home/jovyan/.local/bin:/home/jovyan/.bin:/home/jovyan/.cargo/bin:$PATH
cd /home/jovyan/.bin
mv install-scaphandre-prometheus.sh /home/jovyan/.bin/

# First updates
if [ ! -x /home/jovyan/.local/bin/scaphandre ]; then
  sudo apt-get update
  sudo apt-get install -y pkg-config libssl-dev lsof

  # Install Rust
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source $HOME/.cargo/env
  rustup install 1.65.0 # Install Rust 1.65.0
  rustup override set 1.65.0 # Set the default version to Rust 1.65.0

  # Install Scaphandre
  cd /home/jovyan/.bin/
  if [ ! -d /home/jovyan/.bin/scaphandre ]; then
    git clone https://github.com/hubblo-org/scaphandre.git
  fi
  cd scaphandre
  cargo build --release
  cp ./target/release/scaphandre /home/jovyan/.local/bin/scaphandre
fi
sudo ln -sf /home/jovyan/.local/bin/scaphandre /usr/local/bin/scaphandre

# Run Scaphandre server in the background, with metrics compatible with Prometheus
nohup /home/jovyan/.local/bin/scaphandre prometheus --address=0.0.0.0 --port=8081 --containers > /home/jovyan/.bin/scaphandre.log 2>&1 &

# Install Prometheus
cd /home/jovyan/.bin/
if [ ! -x /home/jovyan/.bin/prometheus-unzipped/prometheus ]; then
  sudo rm -rf /home/jovyan/.bin/prometheus-unzipped
  wget https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz
  tar xzf prometheus-2.52.0.linux-amd64.tar.gz
  mv ./prometheus-2.52.0.linux-amd64 /home/jovyan/.bin/prometheus-unzipped
  rm -rf prometheus-2.52.0.linux-amd64.tar.gz
fi

# Start Prometheus server
PROMETHEUS_CONFIG=$(cat <<EOF
global:
  scrape_interval: 5s

scrape_configs:
  - job_name: 'scaphandre-local'
    static_configs:
      - targets: ['localhost:8081']
EOF
)

echo "$PROMETHEUS_CONFIG" > prometheus.yml
nohup /home/jovyan/.bin/prometheus-unzipped/prometheus --config.file=/home/jovyan/.bin/prometheus.yml --web.listen-address=0.0.0.0:9090 > prometheus.log 2>&1 &
