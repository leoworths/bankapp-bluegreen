#!/bin/bash

# Step 1: Set up AWS and Kubernetes Tools

# Install kubectl (Kubernetes CLI)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# Install helm (Package manager for Kubernetes)
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# Install eksctl (CLI for managing EKS clusters)
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
sudo chmod +x /usr/local/bin/eksctl

# Install awscli (CLI for AWS)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip -y
sudo unzip awscliv2.zip
sudo ./aws/install

# Step 2: Connect to AWS EKS Cluster
# Create an EKS cluster
#eksctl create cluster --name bankapp-cluster --region us-east-1 --nodegroup-name bankapp-node-group --node-type t2.medium --nodes 3 --nodes-min 1 --nodes-max 4 --managed

#delete cluster
#eksctl delete cluster --name bankapp-cluster --region us-east-1 
# Create an IAM role for the EKS cluster
#aws iam attach-role-policy --role-name bankapp-cluster-role --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
#aws iam attach-role-policy --role-name bankapp-cluster-role --policy-arn arn:aws:iam::aws:policy/AmazonEKSServicePolicy
#aws iam attach-role-policy --role-name bankapp-cluster-role --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
#aws iam attach-role-policy --role-name bankapp-cluster-role --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess


aws configure 

# Update kubeconfig for the EKS Cluster
aws eks --region us-east-1 update-kubeconfig --name bankapp-cluster

# Associate OIDC provider with EKS (for IAM roles for service accounts)
eksctl utils associate-iam-oidc-provider --region us-east-1 --cluster bankapp-cluster --approve


# Step 3: Install and Set Up Helm Repositories

# Add Helm Repositories for Argo, Prometheus, and Grafana
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo update


# Step 4: Install Cert-Manager for Kubernetes

# Install Cert-Manager with Helm
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true --version v1.17.0

# Create Kubernetes secret for Cloudflare API Token
kubectl create secret generic cloudflare-api-token --from-literal=apiToken=$CLOUDFLARE_API_TOKEN -n cert-manager

# Apply the ClusterIssuer and certificate
kubectl apply -f ./cert-manager.yaml

# Confirm the certificate is issued
kubectl describe certificate bankapp-certificate -n prod
kubectl describe certificate vault-certificate -n prod
kubectl get clusterissuer letsencrypt-prod
kubectl get certificate bankapp-certificate -n prod
kubectl get certificate vault-certificate -n prod

# Step 5: Install and Configure Ingress Controller

# Install NGINX Ingress Controller via Helm
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace


# Step 6: Set Up EBS CSI Driver

# Create IAM Service Account for EBS CSI Driver
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster bankapp-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --role-only \
  --role-name AmazonEBS_CSI_DriverRole \
  --region us-east-1 \
  --approve

# Install EBS CSI Driver using eksctl (Addon)
eksctl create addon \
  --cluster bankapp-cluster \
  --name ebs-csi \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::637423524942:role/AmazonEBS_CSI_DriverRole \
  --region us-east-1 \
  --force


# Step 7: Install Argo CD and Rollouts

# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Expose Argo CD to the public
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Install Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install Argo Rollout CLI
curl -LO "https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64"
chmod +x ./kubectl-argo-rollouts-linux-amd64
sudo mv ./kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

# Verify Argo Rollouts installation
kubectl argo rollouts version
kubectl argo rollouts dashboard

# Retrieve Argo CD credentials
echo "ArgoCD URL: http://$(kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "ArgoCD Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
echo "ArgoCD Username: admin"



# Port forward to Argo CD
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0


# Promote Argo Rollouts to Production
kubectl argo rollouts promote

# Confirm the setup of storage, PVC, and PV
kubectl get sc
kubectl get pvc
kubectl get pv

# Confirm the status of pods
kubectl get pods -n prod

# Confirm the ingress and service status
kubectl get ingress -n prod
kubectl get svc -n prod

# Confirm certificate is ready
kubectl get certificate -n prod

# Resolve DNS
nslookup www.worths.cloud
kubectl get ingress -n prod
kubectl get svc -n prod
kubectl get svc -n ingress-nginx



##MONITORING
# Install Prometheus with Helm
helm install prometheus prometheus-community/kube-prometheus-stack -f values.yaml -n monitoring --create-namespace 

#Retrieve Prometheus URL
kubectl patch svc prometheus-kube-prometheus-prometheus -p '{"spec":{"type":"LoadBalancer"}}' -n monitoring
prometheus-url=$(kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Prometheus URL: http://$prometheus-url:9090"

#Retrieve Grafana password and URL
kubectl patch svc prometheus-grafana -p '{"spec":{"type":"LoadBalancer"}}' -n monitoring
grafana-url=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Grafana URL: http://$grafana-url"


#patch node exporters & kube-state-metrics services to use LoadBalancer
kubectl patch svc prometheus-node-exporter -p '{"spec":{"type":"ClusterIP"}}' -n monitoring
kubectl patch svc prometheus-kube-state-metrics -p '{"spec":{"type":"ClusterIP"}}' -n monitoring
kubectl patch svc prometheus-blackbox-exporter -p '{"spec":{"type":"ClusterIP"}}' -n monitoring
kubectl patch svc prometheus-alertmanager -p '{"spec":{"type":"LoadBalancer"}}' -n monitoring

#Retrieve node exporter & kube-state-metrics URL
node-exporter-url=$(kubectl get svc prometheus-node-exporter -n monitoring -o jsonpath='{.status.ClusterIP.ingress[0].hostname}')
kube-state-metrics-url=$(kubectl get svc prometheus-kube-state-metrics -n monitoring -o jsonpath='{.status.ClusterIP.ingress[0].hostname}')
blackbox-exporter-url=$(kubectl get svc prometheus-blackbox-exporter -n monitoring -o jsonpath='{.status.ClusterIP.ingress[0].hostname}')
alertmanager-url=$(kubectl get svc prometheus-alertmanager -n monitoring -o jsonpath='{.status.LoadBalancer.ingress[0].hostname}')
echo "Node exporter URL: http://$node-exporter-url:9100"
echo "Kube-state-metrics URL: http://$kube-state-metrics-url:8080"
echo "Blackbox exporter URL: http://$blackbox-exporter-url:9115"
echo "Alertmanager URL: http://$alertmanager-url:9093"


#expose alertmanager to the public
kubectl patch svc prometheus-kube-prometheus-stack-alertmanager -p '{"spec":{"type":"LoadBalancer"}}' -n monitoring
alertmanager-url=$(kubectl get svc prometheus-kube-prometheus-stack-alertmanager -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Alertmanager URL: http://$alertmanager-url:9093"



kubectl expose svc prometheus-kube-prometheus-stack-kube-state-metrics -n monitoring --type=NodePort --port=8080 --target-port=8080 --name=kube-state-metrics-nodeport
kubectl expose svc prometheus-kube-prometheus-stack-node-exporter -n monitoring --type=NodePort --port=9100 --target-port=9100 --name=node-exporter-nodeport



#portforward alertmanager
kubectl port-forward svc/prometheus-kube-prometheus-stack-alertmanager -n monitoring 9093:9093 --address 0.0.0.0



kubectl port-forward svc/prometheus-kube-prometheus-stack-kube-state-metrics -n monitoring 8080:8080 --address 0.0.0.0
kubectl port-forward svc/prometheus-kube-prometheus-stack-node-exporter -n monitoring 9100:9100 --address 0.0.0.0



export alertmanager-url
export kube-state-metrics-url
export node-exporter-url
export blackbox-url


#check alertmanager
kubectl get pods -n monitoring
#check alertmanager
kubectl get svc -n monitoring
#check alertmanager
kubectl get svc prometheus-kube-prometheus-stack-alertmanager -n monitoring -o yaml
#check alertmanager
kubectl get svc prometheus-alertmanager -n monitoring -o yaml

#check configmap
kubectl get configmap prometheus-alertmanager -n monitoring 

#check configmap
kubectl get configmap prometheus-alertmanager -n monitoring -o yaml

#option1 
## Step 8: Create or Edit Alertmanager Configuration
# Create Alertmanager ConfigMap
kubectl create configmap prometheus-alertmanager --from-file=alertmanager.yml -n monitoring

#option2 
# Edit configmap
kubectl edit configmap prometheus-alertmanager -n monitoring

#option 3
# Export Alertmanager ConfigMap to YAML
# This will create a file named prometheus-alertmanager.yaml in the current directory
# You can edit this file to customize the Alertmanager configuration
kubectl get configmap prometheus-alertmanager -n monitoring -o yaml > prometheus-alertmanager.yaml

# Edit the Alertmanager configuration file
vi prometheus-alertmanager.yaml


# Step 9: Apply the Alertmanager Configuration

kubectl apply -f prometheus-alertmanager.yaml -n monitoring

# Step 10: Verify Alertmanager Configuration
kubectl get configmap prometheus-alertmanager -n monitoring -o yaml

# Step 11: Check Alertmanager Pods
kubectl get pods -n monitoring

# step 12: delete alertmanager pod
kubectl delete pod prometheus-alertmanager-0 -n monitoring

# step 13: check alertmanager pod
kubectl get pods -n monitoring

# step 14:update prometheus values.yaml
helm upgrade prometheus prometheus-community/kube-prometheus-stack -f prometheus.yml -n monitoring 






kubectl get configmap -n monitoring

#edit configmap
kubectl edit configmap prometheus-alertmanager -n monitoring
kubectl get configmap prometheus-alertmanager -n monitoring -o yaml > prometheus-alertmanager.yaml
vi prometheus-alertmanager.yaml
kubectl apply -f prometheus-alertmanager.yaml

#check configmap
kubectl get configmap prometheus-alertmanager -n monitoring -o yaml

#check alertmanager
kubectl get pods -n monitoring

#check alertmanager
kubectl get svc -n monitoring

#check alertmanager
kubectl get svc prometheus-kube-prometheus-stack-alertmanager -n monitoring -o yaml
#check alertmanager
kubectl get svc prometheus-alertmanager -n monitoring -o yaml

#get pods
kubectl get pods -n monitoring

#delete pods
kubectl delete pod prometheus-alertmanager-0 -n monitoring

#add email notifications



#get pods
kubectl get pods -n monitoring 






#add email notifications
kubectl patch configmap prometheus-kube-prometheus-prometheus -n monitoring --type merge --patch '{"data":{"prometheus.yml":"\n  alerting:\n    email_configs:\n    - to: \"N5dOo@example.com\"\n"}}'

#configure mail notifications for prometheus
kubectl patch configmap prometheus-kube-prometheus-prometheus -n monitoring --type merge --patch '{"data":{"prometheus.yml":"\n  alerting:\n    alertmanagers:\n    - static_configs:\n      - targets:\n        - \"alertmanager-kube-prometheus-stack-alertmanager.monitoring.svc.cluster.local:9093\"\n"}}'
kubectl patch configmap prometheus-kube-prometheus-prometheus -n monitoring --type merge --patch '{"data":{"prometheus.yml":"\n  rule_files:\n    - /etc/prometheus/rules/prometheus-kube-prometheus-prometheus-rulefiles-0-alerts.yaml\n"}}'
kubectl patch configmap prometheus-kube-prometheus-prometheus -n monitoring --type merge --patch '{"data":{"prometheus.yml":"\n  scrape_configs:\n    - job_name: \"kubernetes-pods\"\n      kubernetes_sd_configs:\n        - role: pod\n      relabel_configs:\n        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]\n          action: keep\n          regex: true\n        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]\n          action: replace\n          target_label: __metrics_path__\n          regex: (.+)\n        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]\n          action: replace\n          target_label: __address__\n          replacement: $1\n"}}'



#patch node-exporter, kube-state-metrics, blackbox-exporter
kubectl patch deployment prometheus-kube-prometheus-stack-node-exporter -n monitoring --patch '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"9100"}}}}}'
kubectl patch deployment prometheus-kube-prometheus-stack-kube-state-metrics -n monitoring --patch '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"8080"}}}}}'
kubectl patch deployment prometheus-kube-prometheus-stack-blackbox-exporter -n monitoring --patch '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"9115"}}}}}'
kubectl patch deployment prometheus-kube-prometheus-stack-alertmanager -n monitoring --patch '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"9093"}}}}}'
kubectl patch deployment prometheus-kube-prometheus-stack-pushgateway -n monitoring --patch '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/port":"9091"}}}}}'



# Step 10: Create GitHub Image Pull Secret (Optional)

# Create GitHub Container Registry Pull Secret
kubectl create secret docker-registry github-container-registry \
  --docker-server=ghcr.io \
  --docker-username=ghcr.io/your-github-username \
  --docker-password=ghcr.io/paste-your-token \
  --docker-email=example@example.com
