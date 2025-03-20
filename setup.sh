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


# Step 2: Connect to AWS EKS Cluster

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
kubectl get clusterissuer letsencrypt-prod
kubectl get certificate bankapp-certificate -n prod


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

# Port forward to Argo CD
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0

# Retrieve Argo CD credentials
echo "ArgoCD URL: http://$(kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "ArgoCD Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
echo "ArgoCD Username: admin"


# Step 8: Install Prometheus, Grafana, and Scraping Configuration

# Install Prometheus with Helm
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
kubectl patch svc prometheus-kube-prometheus-stack-prometheus -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'

# Install Grafana with Helm
helm install grafana grafana/grafana -n monitoring
kubectl patch svc grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'

# Retrieve Prometheus and Grafana URLs
echo "Prometheus URL: http://$(kubectl get svc -n monitoring prometheus-kube-prometheus-stack-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):9090"
echo "Grafana URL: http://$(kubectl get svc -n monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "Grafana Admin Password: $(kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode)"

# Install Prometheus Scraping for Argo Rollouts and Jenkins
kubectl patch deployment argo-rollouts -n argo-rollouts --patch '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/path":"/metrics","prometheus.io/port":"8090"}}}}}'
kubectl patch deployment jenkins --patch '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/path":"/prometheus/metrics","prometheus.io/port":"8080"}}}}}'
kubectl patch deployment argocd-server -n argocd --patch '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true","prometheus.io/path":"/metrics","prometheus.io/port":"8080"}}}}}'


# Step 9: Final Setup and Deployment

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


# Step 10: Create GitHub Image Pull Secret (Optional)

# Create GitHub Container Registry Pull Secret
kubectl create secret docker-registry github-container-registry \
  --docker-server=ghcr.io \
  --docker-username=ghcr.io/your-github-username \
  --docker-password=ghcr.io/paste-your-token \
  --docker-email=example@example.com
