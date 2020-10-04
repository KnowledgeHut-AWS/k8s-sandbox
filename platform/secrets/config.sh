#!/bin/bash

# Let's use colour, shall we?

export Reset='\033[0m'       # Text Reset
export Black='\033[0;30m'        # Black
export Red='\033[0;31m'          # Red
export Green='\033[0;32m'        # Green
export Yellow='\033[0;33m'       # Yellow
export Blue='\033[0;34m'         # Blue
export Purple='\033[0;35m'       # Purple
export Cyan='\033[0;36m'         # Cyan
export White='\033[0;37m'        # White

echo -e "${Green}Configuring Vault${Reset}"

echo -e "${Green}Create an SA and a CRB${Reset}"
kubectl apply -f sa.yaml
kubectl apply -f crb.yaml

# These things are needed to configure the vault k8s auth method
# Set VAULT_SA_NAME to the service account secret name
export VAULT_SA_NAME=$(kubectl get sa vault-auth -n secrets -o jsonpath="{.secrets[*]['name']}")
# Set SA_JWT_TOKEN value to the service account JWT used to access the TokenReview API
export SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_NAME -n secrets -o jsonpath="{.data.token}" | base64 --decode; echo)
# Set SA_CA_CRT to the PEM encoded CA cert used to talk to Kubernetes API
export SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME -n secrets -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)

export K8S_HOST="https://kubernetes.default.svc:443"

export VAULT_PORT=$(kubectl get svc vault-ui -n secrets -o json | jq '.spec.ports[0].nodePort')
export VAULT_ADDR=http://localhost:$VAULT_PORT
export VAULT_TOKEN=root



echo -e "${Green}Enabling k8s auth method (if this has already happened, then there is no output${Reset}"
vault auth enable kubernetes 2> /dev/null

echo -e "${Green}configuring k8s auth method${Reset}"
vault write auth/kubernetes/config \
        token_reviewer_jwt="$SA_JWT_TOKEN" \
        kubernetes_host="$K8S_HOST" \
        kubernetes_ca_cert="$SA_CA_CRT"


echo -e "${Green}Create a policy for reading a secret${Reset}"
vault policy write myapp-kv-ro - <<EOF
path "secret/data/myapp/*" {
    capabilities = ["read", "list"]
}
EOF

echo -e "${Green}And a secret${Purple}suP3rsec(et!${Reset}"
vault kv put secret/myapp/config username='appuser' \
        password='suP3rsec(et!' \
        ttl='30s'

echo -e "${Green}create a role bound to vault-auth SA${Reset}" 
vault write auth/kubernetes/role/myapprole \
        bound_service_account_names=vault-auth \
        bound_service_account_namespaces=vault \
        policies=myapp-kv-ro \
        ttl=24h

echo -e "${Red}At this point you're meant to run the stuff in the verify function manually one command at a time, to verify the installation${Reset}"
function verify {
    # You're meant to run this manually, 1 line at a time. I've put this code in a function so that it doesn't run as part of the outter script
    # Notice how we talk to vault at the addres, http://vault:8200, because we're inside the cluster
    kubectl run mypine --image alpine -it --rm --serviceaccount=vault-auth -n secrets
    apk add curl jq
    echo "Confirm connectivity" 
    curl -s http://vault:8200/v1/sys/seal-status | jq 
    echo "Get the SA/s token" 
    KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token) 
    echo "${KUBE_TOKEN}" 
    echo "Confirm token" 
    curl -sL --request POST --data '{"jwt": "'"$KUBE_TOKEN"'", "role": "myapprole"}' http://vault:8200/v1/auth/kubernetes/login | jq
}

echo -e "${Green}Configuring an init container${Reset}"
kubectl apply -f agent-autoauth-config.yaml -n secrets

echo -e "${Green}Create a sample app with nginx which will just return a page with the secret from vault we created earlier${Reset}"
kubectl apply -f example-pod-spec.yaml -n secrets

echo -e "${Green}${Reset}"
kubectl port-forward pod/vault-agent-example 8080:80 -n secrets

