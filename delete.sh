#!/bin/bash

#delete all vault resources
kubectl delete namespace vault

helm uninstall vault -n vault
kubectl delete namespace prod
kubectl delete serviceaccount vault-auth -n prod
kubectl delete serviceaccount vault-auth -n default
kubectl exec -it vault-0 -n vault -- vault auth disable kubernetes


kubectl delete storageclass ebs-csi-sc


#delete all resources in prod namespace
kubectl delete namespace prod


kubectl delete secret cloudflare-api-token

helm uninstall cert-manager --namespace cert-manager
kubectl delete namespace cert-manager

kubectl delete -f ./cert-manager.yaml
kubectl delete certificate bankapp-certificate -n prod
kubectl delete clusterissuer letsencrypt-prod

helm uninstall prometheus -n monitoring
helm uninstall grafana -n monitoring
kubectl delete namespace monitoring

kubectl delete namespace argocd
kubectl delete namespace argo-rollouts

helm uninstall ingress-nginx --namespace ingress-nginx
kubectl delete namespace ingress-nginx

kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml


#delete all kms resources
aws kms delete-key-policy --key-id $KMS_KEY_ID --policy '{"Version":"2012-10-17","Statement":[{"Sid":"Enable IAM User Permissions","Effect":"Allow","Principal":{"AWS":"*"},"Action":"kms:*","Resource":"*"}]}'
aws kms disable-key --key-id $KMS_KEY_ID
aws kms schedule-key-deletion --key-id $KMS_KEY_ID --pending-window-in-days 7



#delete ebs csi addon
eksctl delete addon --cluster bankapp-cluster --name ebs-csi --region us-east-1

#delete iam service account
eksctl delete iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster bankapp-cluster \
  --region us-east-1

#delete ebs csi driver role
aws iam delete-role --role-name AmazonEBS_CSI_DriverRole --region us-east-1

kubectl delete storageclass ebs-csi-sc

kubectl delete pvc mysql-pvc -n vault

kubectl delete pvc vault-pvc -n vault

kubectl delete pvc --all -n vault

kubectl delete pv --all


# 1. Detach policy
aws iam detach-role-policy \
  --role-name vault-role \
  --policy-arn arn:aws:iam::637423524942:policy/VaultKmsUnsealPolicy

# 2. Delete IAM policy
aws iam delete-policy \
  --policy-arn arn:aws:iam::637423524942:policy/VaultKmsUnsealPolicy

# 3. Delete EKS IAM service account
eksctl delete iamserviceaccount \
  --name vault-auth \
  --namespace vault \
  --cluster bankapp-cluster \
  --region us-east-1

# 4. Remove policy file
rm vault-kms-policy.json
