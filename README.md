# 🌱🌍♻️ L1EcoVRE (a [GreenDIGIT](https://greendigit-project.eu/) project)

### Overview
This is the repository that contains the configuration files for the Helm Zero to Jupyter Kubernetes cluster with Scaphandre. This is an easy way to configure and deploy your application in Kubernetes using Scaphandre and JupyterHub for RI managers, which offer energy and sustainable metrics that integrate natively with [EcoJupyter](https://github.com/g-uva/EcoJupyter).

*This work is funded from the European Union’s Horizon Europe research and innovation programme through the [GreenDIGIT project](https://greendigit-project.eu/), under the grant agreement No. [101131207](https://cordis.europa.eu/project/id/101131207)*.

<div style="display:flex;align-items:center;width:100%;">
  <img src="static/EN-Funded-by-the-EU-POS-2.png" alt="EU Logo" width="250px">
  <img src="static/cropped-GD_logo.png" alt="GreenDIGIT Logo" width="110px" style="margin-right:100px">
</div>


#### Access to server and infrastructure deployment
This is a configuration is deployed at the server: https://greendigit-ecojupyter.sztaki.hu//.
> If you want to have access to the server (filesystem and others), please contact g.j.teixeiradepinhoferreira@uva.nl.

### Usage
If you have access to access to the [deployment server](https://greendigit-ecojupyter.sztaki.hu/), then you just need to follow these steps:
1. Install and run Scaphandre and Prometheus.
2. *Run your workflow.*
3. Export CSV metrics (and download them).

> This configuration is to be used with [EcoJupyter](https://github.com/g-uva/EcoJupyter).

#### 1. Install and run Scaphandre, Prometheus, and Grafana.
To install Scaphandre and Prometheus, you just need to copy and run this command on your notebook terminal.
The installer downloads prebuilt binaries, checks their checksums, and prevents concurrent installations. Output is saved to `~/.bin/telemetry-install.log`.
```sh
bash /srv/telemetry-installer/install.sh
```

The local configuration also applies this installer to the Jupyter VRE Workflow **Install Telemetry** button. Scaphandre requires RAPL energy counters. On a VM without these counters, installation reports that energy telemetry is unavailable; Prometheus still runs. VM energy measurements require Scaphandre on the physical hypervisor and its exported `/var/scaphandre` data, with guest Scaphandre configured using `--vm`. Retrying installation cannot create hardware counters.

<!-- Additionally, install and serve Grafana at `:3000` with the following script:
```sh
sudo apt-get install -y software-properties-common software-properties-common gnupg2
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://apt.grafana.com/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/grafana.gpg

echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt-get update -y
sudo apt-get install -y grafana

# Start Grafana:
# Allows Grafana embedding (e.g., in <iframe>).
sudo sed -i 's/^[;#]*\s*allow_embedding\s*=\s*false/allow_embedding = true/' /etc/grafana/grafana.ini
sudo grafana-server --homepath=/usr/share/grafana --config=/etc/grafana/grafana.ini &
``` -->

#### 2. Run your workflow (notebook examples)
##### 2.1 IceNet notebook example
The local Hub configuration clones this example into `/home/jovyan/icenet-notebook`,
but cloning does not install its dependencies. Before starting an experiment, run
these commands in the JupyterLab terminal (the example requires Python 3.9–3.11):
```sh
if [ ! -d /home/jovyan/icenet-notebook ]; then
  git clone https://github.com/g-uva/egi-ice-net-example.git /home/jovyan/icenet-notebook
fi
sudo apt-get update
sudo apt-get install -y --no-install-recommends libhdf5-dev libnetcdf-dev libudunits2-0
/opt/conda/bin/python -m pip install --user -r /home/jovyan/icenet-notebook/requirements.txt 'tensorflow-probability==0.23.0'
```

Using the kernel's Python interpreter installs the packages into the persistent
`/home/jovyan/.local` directory. After installation, restart the notebook kernel
and verify `import tensorflow, icenet, xarray` before clicking **Restart experiment**
in Jupyter VRE Workflow. TensorFlow Probability 0.23 matches the example's
TensorFlow 2.15 dependency; newer Probability releases require newer TensorFlow.
Native libraries installed with `apt-get` need to be
installed again if the user pod is recreated.

##### 2.2 Other notebooks (WIP)
- [Workflow 1](https://github.com/shashikantilager/data-center-characterization) *(Just for reference, please read the instructions to put the data into the `/data/...` folder).*
    1. [Notebook from Shashikant](https://drive.google.com/file/d/1FUi9xw3Y0VuzUhbqicEM2HnDONcNtgwB/view?usp=drive_link)
    2. [Dataset 01](https://drive.google.com/file/d/1cW7jggF2-TmPBrQEpJDtx0vOYs5Me8Cg/view?usp=drive_link)
    3. [Dataset 02](https://drive.google.com/file/d/1svqM1wrkxtCk9nZ90aJEvXGlBnNr8kRN/view?usp=drive_link) 
- [Workflow 2](https://github.com/atlarge-research/2024-icpads-hpc-workload-characterization)

##### Exiting the notebook
For the moment, in order to "kill" the pod, the server must be stopped. To do that you must go to `File > Hub Control Panel` and click the button `Stop my server`


#### 3. Export CSV metrics (and download them).
First you must run this script to create a `~/scripts/` folder and download a couple of scripts inside to run them.
```sh
mkdir -p /home/jovyan/scripts/
wget -qO /home/jovyan/scripts/export_metrics.py https://raw.githubusercontent.com/g-uva/jupyterhub-scaphandre-monitor/refs/heads/master/export-metrics-service/export-metrics-pod/export_metrics_ownpod_container.py
wget -qO /home/jovyan/scripts/requirements.txt https://raw.githubusercontent.com/g-uva/jupyterhub-scaphandre-monitor/refs/heads/master/export-metrics-service/export-metrics-pod/requirements.txt
```

Finally, execute this command to create the metrics. The ouput folder should be `~/export-metrics/...`.
```sh
cd /home/jovyan/scripts/
pip install -r requirements.txt
sudo -E python3 /home/jovyan/scripts/export_metrics.py
```

#### 3.1 (Bonus) Zip and download metrics
```sh
cd /home/jovyan/scripts/
wget -qO /home/jovyan/scripts/package_metrics.py https://raw.githubusercontent.com/g-uva/jupyterhub-scaphandre-monitor/refs/heads/master/export-metrics-service/export-metrics-pod/package_metrics.py
sudo -E python3 /home/jovyan/scripts/package_metrics.py
```

---
> WIP @goncalo
> This section is for the infrastructure manager only. Please disregard if you're an end user of the Notebook / Plugin.
```sh
ri_site_container_<id>-experiment/  
├── ro-crate-metadata.json # (FAIR metadata + sustainability extensions)  
├── data/
│  │   ├── <id>_metrics.csv
│  ├── output/
│  │   └── workflow_output_files/  
│  ├── input/
│  │   └── workflow_input_files/
│  └── logs/
│      └── energy_log.json  
├── executed/  
│  └── jupyter-notebook.ipynb
├── environment/
│  ├── requirements.txt/environment.yml
│  └── k8s.yml/ansible_config/cloud_formation_config  
└── README.md
```

## Infrastructure configuration

### Full reset and rebuild on gd4

Run this entire snippet in **Bash on the gd4 host**, outside Jupyter. Docker, Minikube, kubectl, and Helm must already be installed, and `.env` must contain `JHUB_PASSWORD`.

**This deletes the Minikube cluster and its notebook volumes, including user files and installed packages. Back up anything you need first.** The host's existing swap configuration remains in place.

```bash
(
set -euo pipefail
cd /home/goncalo/L1EcoVRE

set -a
source .env
set +a
: "${JHUB_PASSWORD:?Set JHUB_PASSWORD in .env before rebuilding}"

minikube delete -p minikube

minikube start -p minikube \
  --driver=docker --cpus=2 --memory=2560 \
  --extra-config=apiserver.service-node-port-range=9091-32767

docker update --memory 2560m --memory-swap 3584m minikube

kubectl create namespace jhub

kubectl create secret generic hub-password-secret -n jhub \
  --from-literal=password="$JHUB_PASSWORD"

kubectl create configmap telemetry-installer -n jhub \
  --from-file=telemetry-installer/install.sh \
  --from-file=telemetry-installer/safe_telemetry.py

kubectl create configmap starter-notebook -n jhub \
  --from-file=tutorial-notebook/GD_EcoJupyter_Tutorial.ipynb

kubectl create configmap stress-notebook -n jhub \
  --from-file=tutorial-notebook/GD_EcoJupyter_StressTest.ipynb

kubectl create configmap track-notebook -n jhub \
  --from-file=configmap-track-experiment-service/notebook_tracker_experimentid.py

helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update

helm upgrade --install jhub jupyterhub/jupyterhub \
  -n jhub --version 4.4.2 \
  --values jhub-config-local.yaml \
  --wait --timeout 5m

kubectl -n jhub patch svc proxy-public --type=merge \
  -p "{\"spec\":{\"externalIPs\":[\"$(minikube ip -p minikube)\"]}}"

kubectl apply -f dynamic-nodeport-service/dynamic-nodeport-service.yaml

kubectl get nodes
kubectl get pods -A
)
```

Then reopen JupyterHub and log in. Your notebook home will be fresh; install `jupyter-vre-workflow` again and restart your Jupyter server before using its telemetry button. Rebuilding does not supply the VM's missing energy counters.

### General infrastructure setup

> The reference for the steps come from the official Zero to Jupyter documentation.
0. Changing permissions (for development).
```sh
# If you're using SSH extension for VS code, make sure you have writing permissions:
ls -l ~/<your_file>
ls -ld ~ # Pointing to the /home/user/ root.

# As long as you have sudo access rights, you should set this as follows:
sudo chown -R $(whoami):$(whoami) ~ # Extending the automatic reading/writing access rights to the home folder.
```

1. Install Docker.
2. Install Helm.
3. Install Kubernetes and `kubectl`.
4. Install Minikube.
```sh
# We're using minikube as the Kubernetes managed environment.
# The port range must be allowed from the API Server control, in order to expose the individual ports from users.

# minikube start --extra-config=apiserver.service-node-port-range=9091-9100,30000-32767
minikube start --extra-config=apiserver.service-node-port-range=9091-32767

# minikube start \
#   --driver=docker \
#   --cpus=4 --memory=6g \
#   --extra-config=apiserver.service-node-port-range=9091-9100,30000-32767

```
4. Install all the repositories from Helm using the `yaml` files. There are two main flavours that we can choose from:
    1. `/home/goncalo/jupyterhub-scaphandre-monitor/jhub-config.yaml`: configuration for Spawner with Scaphandre sidecar.
    2. `/home/goncalo/jupyterhub-scaphandre-monitor/jhub-config-local.yaml`: configuration for Scaphandre to be installed locally.
```sh
# -------------
# JupyterHub chart installation.
# -------------
kubectl create namespace jhub --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap telemetry-installer -n jhub \
  --from-file=telemetry-installer/install.sh \
  --from-file=telemetry-installer/safe_telemetry.py \
  --dry-run=client -o yaml | kubectl apply -f -
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update
helm install jhub jupyterhub/jupyterhub \
  -n jhub --create-namespace \
  --values ./jhub-config-local.yaml # Point to the configuration file for JupyterHub.

# -------------
# Monitoring (Prometheus + Grafana) chart installation.
# -------------
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --values ./monitoring-config.yaml # Point to the configuration file for Monitoring.

# Update any repository (in case the YAML file is changed).
# Note: replace the namespace and repository accordingly.
helm upgrade --install jhub jupyterhub/jupyterhub -n jhub --values ./jhub-config-local.yaml

# Port-binding for a permanent port-forward, not terminal dependency
# 1. The "typical" way would be:
kubectl -n jhub port-forward svc/proxy-public 8000:80 # or http

# This however, poses some problems. As even with `disown`, the terminal is tied to the serving.
# If we just change the reverse-proxy for the created EXTERNAL-IP and patch it, we have Kubernetes receiving
kubectl -n jhub patch svc proxy-public \
  --type='merge' \
  -p '{"spec":{"externalIPs":["192.168.49.2"]}}'

# Setting the password secret: `hub-password-secret` is recognised by JupyterHub automatically.
# We assume that JHUB_PASSWORD is set in .env
set -a
source .env
set +a
kubectl create secret generic hub-password-secret -n jhub --from-literal=password=$JHUB_PASSWORD

# For PVC prepopulated files.
kubectl create configmap starter-notebook \
  --from-file=GD_EcoJupyter_Tutorial.ipynb=/home/ubuntu/JupyterK8sMonitor/tutorial-notebook/GD_EcoJupyter_Tutorial.ipynb \
  -n jhub

kubectl create configmap stress-notebook \
  --from-file=GD_EcoJupyter_Tutorial.ipynb=/home/ubuntu/JupyterK8sMonitor/tutorial-notebook/GD_EcoJupyter_StressTest.ipynb \
  -n jhub

kubectl create configmap track-notebook \
  --from-file=notebook_tracker_experimentid.py=/home/ubuntu/JupyterK8sMonitor/configmap-track-experiment-service/notebook_tracker_experimentid.py \
  -n jhub

# kubectl create configmap shashikant-notebook-example \
#   --from-folder=shashikant-notebook-example=/home/ubuntu/JupyterK8sMonitor/shashikant-notebook/ \
#   -n jhub

# To restart the deployment rollout (in case some changes need to be propagated)
kubectl rollout restart deployment hub -n jhub
```

4. Apply PodMonitor and Nginx configurations.
5. The app should be ready to use! 👍

#### Metrics files
> *WIP @goncalo (might delete*)
- Files to be run **outside** of the cluster (this should be done, not to worry about the Kubernetes-only user):
     - `pod-reader-rolebinding.yaml`: It allows Jupyter to read Kube and Pod configuration from within the Pod.
          - You must run `kubectl apply -f export-metrics-pod/pod-reader-rolebinding.yaml` during the configuration on the local server, outside of the Kubernetes cluster.
---

### Export metrics service
The export metrics service allows the user to easily and conveniently export its container/pod metrics with as little tweaking as possible. The folder structure should look like this:

```sh
export-metrics/
└── 1a2b3c4d_jupyter-goncalo_jupyter-experiment/
    ├── scaph_host_energy_microwatts.csv
    ├── scaph_process_power_consumption.csv
    └── ... other scaph_*.csv files
ro-crate-metadata.json
```

#### Export metrics approaches
Currently metrics can be exported in two ways:
1. Locally if you have access to your server. `jupyterhub-scaphandre-monitor/export-metrics-service/export-metrics-local`.
2. From your container/pod. `jupyterhub-scaphandre-monitor/export-metrics-service/export-metrics-pod`.

*We're going to describe only the second option as it requires Scaphandre/Prometheus installation from within the Pod/Container (JupyterNotebook).*

#### Example notebooks/workflows
<!-- - Download the script files from the [Google Drive folder](https://drive.google.com/drive/folders/1NuyVLMKWd6GW7lNOmeb9H2g25PlrpqXT?usp=drive_link). -->

**Notebook and package files:**
- `analysis.ipynb`: example notebook file provided by Shashikant.
- `requirements.txt`: list of packages to be installed by Python (for now it is manual).
    - Run `pip install -r requirements.txt` to install the packages needed to run the notebook.

**List of files and actions:**
- `export_metrics_ownpod.py`: copy it to the `root` (typically `/home/jovyan`).
- `export-metrics.sh`: copy it to the `root` + execute `chmod +x ./export-metrics.sh` in order to make it executable.
