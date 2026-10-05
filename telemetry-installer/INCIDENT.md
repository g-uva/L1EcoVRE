# gd4 telemetry installation incident, 2026-10-05

The saved notebook logs show streaming installer connections closing at 17:25:30 and 17:31:40 CEST. Hub activity requests subsequently timed out at 17:48. After a cluster restart, DNS resolution and Hub requests failed again around 18:03. Docker/containerd were killed and restarted around 18:12; the Minikube container exited with code 255. No OOM-killer entries were found in the host kernel logs inspected, so an OOM kill is not proven.

The host has 3.8 GiB RAM and initially had no swap. Minikube's limit was 3 GiB. The installed jupyter-vre-workflow 0.1.259 installer compiled Scaphandre with unrestricted Cargo parallelism, deleted its build cache on retries, allowed concurrent requests, and did not persist its streamed output. Resource exhaustion during compilation is the leading explanation for the repeated loss of cluster responsiveness.

The deployed fix uses the official prebuilt Scaphandre v1.0.0 release package and Prometheus 2.52.0 archive, checks download checksums, reuses installed executables, locks both API and shell installs, retains logs, and bounds the API installation to ten minutes. Browser disconnections do not interrupt log draining or launch another installation. Prometheus shutdown is awaited before restarting it, and startup readiness is checked. Notebook limits are 1 CPU and 1280 MiB RAM, with requests of 0.1 CPU and 512 MiB RAM.

Host remediation enabled a persistent 4 GiB `/swapfile` through `/etc/fstab`. The existing Minikube container was updated to a 2560 MiB memory limit and a 3584 MiB combined memory/swap limit; its persisted profile memory setting was also updated without deleting the cluster or PVCs. JupyterHub chart 4.4.2 was upgraded using the local configuration and the telemetry-installer ConfigMap.

Verification: binary downloads and checksums succeeded in the actual notebook pod; the installer API returned HTTP 409 under a held lock; retries used the prebuilt installer; a fresh notebook kernel started and executed Python; all Kubernetes pods recovered and the node was Ready. Repeated installation exposed and fixed a Prometheus port-release race.

Separate hardware limitation: `/sys/class/powercap` exposes no energy counters on this VM. Scaphandre panics if started with the physical RAPL sensor. The installer now reports this limitation without starting the failing exporter. Prometheus runs, but energy measurements need physical-host counters or hypervisor-exported Scaphandre data; no synthetic measurements are generated.

Notebook logs: `~/.bin/telemetry-install.log`, `~/.bin/prometheus.log`, `~/.bin/scaphandre.log`.

Saved pre-recovery server logs on gd4 are under `/var/lib/docker/volumes/minikube/_data/log/pods/jhub_jupyter-goncalo_059a827c-0f93-44ca-a2b4-b2f4bc535fe2/notebook/` (root access required). VS Code's ptyhost log recorded terminal replay metadata, but did not expose the terminal's complete scrollback to this agent.
