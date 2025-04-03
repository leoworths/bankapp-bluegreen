#!/bin/bash

#install vault with helm
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update


#create vault namespace
kubectl create namespace vault 
kubectl create namespace prod

#create vault service account
kubectl create serviceaccount vault-auth -n prod
kubectl create serviceaccount vault-auth -n default

#copy vault-values.yaml file to vault pod
nano vault-values.yaml
or 
vi vault-values.yaml

#install vault helm chart with values
helm install vault hashicorp/vault -n vault -f vault-values.yaml --set server.dev.enabled=false


#check vault installation
kubectl get all -n vault

#kubectl config set-context --current --namespace=vault

#initialize vault
kubectl exec -it vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json

#unseal the vault
kubectl exec -it vault-0 -- vault operator unseal $(cat cluster-keys.json | jq -r '.unseal_keys_b64[0]')

#login to vault
kubectl exec -it vault-0 -- vault login $(cat cluster-keys.json | jq -r '.root_token')

#join vault pods to raft cluster
kubectl exec -it vault-1 -- vault operator raft join https://vault-0.vault.svc.cluster.local:8200
kubectl exec -it vault-2 -- vault operator raft join https://vault-0.vault.svc.cluster.local:8200



#unseal all vault pods
kubectl exec -it vault-1 -- vault operator unseal $(cat cluster-keys.json | jq -r '.unseal_keys_b64[0]')
kubectl exec -it vault-2 -- vault operator unseal $(cat cluster-keys.json | jq -r '.unseal_keys_b64[0]')


#verify vault
kubectl exec -it vault-0 -- vault status

#list pods
kubectl get pods -n vault

#check cluster health
kubectl exec -it vault-0 -- vault status
kubecl exec -it vault-1 -- vault status
kubectl exec -it vault-2 -- vault status



#add ingress file
nano vault-ingress.yaml
or
vi vault-ingress.yaml

#install vault ingress
kubectl apply -f vault-ingress.yaml -n vault

#get service ip for dns resolution
kubectl get svc -n vault


#enable kubernetes auth
kubectl exec -it vault-0 -- vault auth enable kubernetes


#configure kubernetes auth for prod namespace
kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/config \
  token_reviewer_jwt="$(kubectl get secret -n kube-system $(kubectl get sa vault-auth -n prod -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" | base64 --decode)" \
  kubernetes_host="$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}')" \
  kubernetes_ca_cert="$(kubectl get secret -n kube-system $(kubectl get sa vault-auth -n prod -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data['ca.crt']}" | base64 --decode)"

#kubenetes auth default namespace
kubectl exec -it vault-0 -n default -- vault write auth/kubernetes/config \
  token_reviewer_jwt="$(kubectl get secret -n kube-system $(kubectl get sa vault-auth -n default -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" | base64 --decode)" \
  kubernetes_host="$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}')" \
  kubernetes_ca_cert="$(kubectl get secret -n kube-system $(kubectl get sa vault-auth -n default -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data['ca.crt']}" | base64 --decode)"



#create policy file
cat <<EOF > /tmp/policy.hcl
path "secret/data/mysql*" {
  capabilities = ["create", "read", "list"]
}
path "secret/data/frontend*" {
  capabilities = ["create", "read", "list"]
}
EOF

#copy policy file to vault pod
kubectl cp /tmp/policy.hcl vault-0:/tmp/policy.hcl -n vault

#write policy file
kubectl exec -it vault-0 -n vault -- vault policy write my-policy /tmp/policy.hcl

#configure kubernetes auth role
kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/role/vault-role \
  bound_service_account_names=vault-auth \
  bound_service_account_namespaces="prod,default" \
  role_name=vault-role \
  policies=my-policy \
  ttl=24h


#verify kubernetes auth role
kubectl exec -it vault-0 -n vault -- vault read auth/kubernetes/role/vault-role

#enable secret engine
kubectl exec -it vault-0 -n vault -- vault secrets enable -path=secret kv-v2

#add secrets to vault
kubectl exec -it vault-0 -n vault -- vault kv put secret/mysql \
  MYSQL_ROOT_PASSWORD=Test@123 \
  MYSQL_DATABASE= bankapp

kubectl exec -it vault-0 -n vault -- vault kv put secret/frontend \
  MYSQL_USER=root \
  MYSQL_PASSWORD=Test@123

#access secrets from vault
kubectl exec -it vault-0 -n vault -- vault kv get secret/mysql
kubectl exec -it vault-0 -n vault -- vault kv get secret/frontend


#add cloudflare secret to vault
kubectl exec -it vault-0 -n vault -- vault kv put secret/cloudflare/api-token \
  apiToken=YOUR_API_TOKEN

#access cloudflare secret from vault
kubectl exec -it vault-0 -n vault -- vault kv get secret/cloudflare/api-token

#retrieve the Cloudflare API token from Vault

export CLOUDFLARE_API_TOKEN=$(kubectl exec -it vault-0 -n vault -- vault kv get -field=apiToken secret/cloudflare/api-token)
echo $CLOUDFLARE_API_TOKEN



#create directory for audit logs
kubectl exec -it vault-0 -n vault -- mkdir -p /var/log/vault
mkdir -p /var/log/vault
#audit logs
kubectl exec -it vault-0 -n vault -- vault audit enable file file_path=/var/log/vault_audit.log

#verify audit logs
kubectl exec -it vault-0 -n vault -- vault audit list

#read audit logs
kubectl exec -it vault-0 -n vault -- cat /var/log/vault_audit.log
#tail audit logs
kubectl exec -it vault-0 -n vault -- tail -f /var/log/vault_audit.log
#disable audit logs
kubectl exec -it vault-0 -n vault -- vault audit disable file

kubectl exec -it vault-0 -n vault -- vault audit list
#delete audit logs
kubectl exec -it vault-0 -n vault -- rm /var/log/vault_audit.log

kubectl exec -it vault-0 -n vault -- vault audit list

#access vault ui with domain name
https://vault.worths.cloud/ui/vault/
#access vault ui with ip address
https://10.1.0.1:8200/ui/vault/
--------------------------------------------

#add cloudflare certificate and key to vault
kubectl exec -it vault-0 -n vault -- vault kv put secret/cloudflare/certificate \
  cert=YOUR_CERTIFICATE \
  key=YOUR_PRIVATE_KEY

#access cloudflare certificate and key from vault
kubectl exec -it vault-0 -n vault -- vault kv get secret/cloudflare/certificate

#retrieve the Cloudflare certificate and key from Vault

export CLOUDFLARE_CERTIFICATE=$(kubectl exec -it vault-0 -n vault -- vault kv get -field=cert secret/cloudflare/certificate)
export CLOUDFLARE_PRIVATE_KEY=$(kubectl exec -it vault-0 -n vault -- vault kv get -field=key secret/cloudflare/certificate)

echo $CLOUDFLARE_CERTIFICATE
echo $CLOUDFLARE_PRIVATE_KEY

kubectl create secret generic cloudflare-cert-secret \
  --from-literal=cert="$CLOUDFLARE_CERTIFICATE" \
  --from-literal=key="$CLOUDFLARE_PRIVATE_KEY" \
  --namespace vault

#verify the secret
kubectl get secret cloudflare-cert-secret -n vault



# update helm values
helm upgrade --install vault hashicorp/vault -n vault -f vault-values.yaml



#access vault
kubectl port-forward svc/vault 8200:8200 -n vault
kubectl port-forward vault-0 8200:8200 -n vault
#http://localhost:8200/ui


#forward port
kubectl port-forward svc/vault 8200:8200 -n vault

#access vault ui
http://localhost:8200/ui

##if want to access vault via loadbalancer
kubectl get svc -n vault

#access vault ui
http://<EXTERNAL-IP>:8200/ui/vault/
https://<EXTERNAL-IP>:8200/ui/vault/


kubectl logs -f vault-0 -n vault


