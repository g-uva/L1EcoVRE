#!/bin/bash
set -euo pipefail
install_dir="${HOME}/.bin"
mkdir -p "$install_dir"
exec 9>"$install_dir/telemetry-install.lock"
flock -n 9 || { echo 'Another telemetry installation is running.'; exit 75; }
exec > >(tee -a "$install_dir/telemetry-install.log") 2>&1
echo "Telemetry installation started: $(date -Is)"
tmp_dir=$(mktemp -d "$install_dir/install.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

# Use the official release package; never compile Rust in a notebook pod.
if [ ! -x "$install_dir/scaphandre" ]; then
  [ "$(uname -m)" = x86_64 ] || { echo 'This installer supports x86_64 only.'; exit 1; }
  curl -fL --retry 2 --connect-timeout 15 --max-time 180 \
    https://github.com/hubblo-org/scaphandre/releases/download/v1.0.0/scaphandre_v1.0.0-deb12_amd64.deb \
    -o "$tmp_dir/scaphandre.deb"
  echo "2ea5325164d9e44663f75719329259e2eca9586e9c83862950f206593794cc43  $tmp_dir/scaphandre.deb" | sha256sum -c -
  dpkg-deb -x "$tmp_dir/scaphandre.deb" "$tmp_dir/scaphandre"
  "$tmp_dir/scaphandre/usr/bin/scaphandre" --version
  install -m 755 "$tmp_dir/scaphandre/usr/bin/scaphandre" "$install_dir/scaphandre"
fi
"$install_dir/scaphandre" --version

if [ ! -x "$install_dir/prometheus-unzipped/prometheus" ]; then
  curl -fL --retry 2 --connect-timeout 15 --max-time 180 \
    https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz \
    -o "$tmp_dir/prometheus.tar.gz"
  curl -fL --retry 2 --connect-timeout 15 --max-time 60 \
    https://github.com/prometheus/prometheus/releases/download/v2.52.0/sha256sums.txt \
    -o "$tmp_dir/checksums"
  expected=$(awk '$2 == "prometheus-2.52.0.linux-amd64.tar.gz" {print $1}' "$tmp_dir/checksums")
  [ -n "$expected" ]
  echo "$expected  $tmp_dir/prometheus.tar.gz" | sha256sum -c -
  tar xzf "$tmp_dir/prometheus.tar.gz" -C "$tmp_dir"
  mv "$tmp_dir/prometheus-2.52.0.linux-amd64" "$install_dir/prometheus-unzipped"
fi
cat > "$install_dir/prometheus.yml" <<'EOF'
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: scaphandre
    static_configs:
      - targets: ['localhost:8081']
EOF
"$install_dir/prometheus-unzipped/promtool" check config "$install_dir/prometheus.yml"
pkill -f '[s]caphandre prometheus' || true
pkill -f '[p]rometheus.*--config.file=.*prometheus.yml' || true
# Wait for old processes to release their ports and the TSDB lock.
for attempt in $(seq 1 30); do
  if ! pgrep -f '[p]rometheus.*--config.file=.*prometheus.yml' >/dev/null; then
    break
  fi
  sleep 1
done
if pgrep -f '[p]rometheus.*--config.file=.*prometheus.yml' >/dev/null; then
  echo 'Existing Prometheus did not stop within 30 seconds.'
  exit 1
fi
# Release the inherited flock descriptor in daemons.
nohup "$install_dir/prometheus-unzipped/prometheus" \
  --config.file="$install_dir/prometheus.yml" --web.listen-address=0.0.0.0:9090 \
  --storage.tsdb.path="$install_dir/prometheus-data" --storage.tsdb.retention.time=2d \
  --storage.tsdb.retention.size=256MB \
  > "$install_dir/prometheus.log" 2>&1 < /dev/null 9>&- &
prometheus_pid=$!
for attempt in $(seq 1 30); do
  if curl -fsS --max-time 2 http://localhost:9090/-/ready >/dev/null 2>&1; then
    break
  fi
  kill -0 "$prometheus_pid" 2>/dev/null || { echo 'Prometheus exited; see ~/.bin/prometheus.log.'; exit 1; }
  sleep 1
done
curl -fsS --max-time 2 http://localhost:9090/-/ready >/dev/null
if ! find -L /sys/class/powercap -name energy_uj -print -quit 2>/dev/null | grep -q .; then
  echo 'Binaries installed; Prometheus started. Energy telemetry is unavailable: no RAPL energy counters are visible under /sys/class/powercap.'
  echo 'Check the host RAPL kernel modules and /sys mounts; an accessible powercap directory can still be empty.'
  echo 'Scaphandre needs physical-host RAPL counters or hypervisor-provided /var/scaphandre data with --vm. Installing again cannot add these counters.'
  exit 1
fi
nohup "$install_dir/scaphandre" prometheus --address=0.0.0.0 --port=8081 --containers \
  > "$install_dir/scaphandre.log" 2>&1 < /dev/null 9>&- &
for attempt in $(seq 1 30); do
  if curl -fsS --max-time 2 http://localhost:8081/metrics >/dev/null 2>&1 && \
     curl -fsS --max-time 2 http://localhost:9090/-/ready >/dev/null 2>&1; then
    echo "Telemetry ready: $(date -Is)"
    exit 0
  fi
  sleep 1
done
echo 'Telemetry failed to start. Check ~/.bin/scaphandre.log and ~/.bin/prometheus.log.'
exit 1
