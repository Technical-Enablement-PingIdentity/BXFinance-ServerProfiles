#!/usr/bin/env sh

test -z "${REF}" && REF=$(git rev-parse --abbrev-ref HEAD)
set -a
# shellcheck source=@localSecrets
test -f ./ci_tools/@localSecrets && . ./ci_tools/@localSecrets

case "${REF}" in
  master ) 
    REACT_APP_ENV_NAME=Prod
    ACME_SERVER_ENV_NAME="Let's Encrypt"
    FQDN="demo.bxfinance.org"
    PING_IDENTITY_DEVOPS_DNS_ZONE="demo.bxfinance.org"
    ## used for prefixing
    ENV=""
    ;;
  * )
    if test "${REF}" != "qa" && test "${REF}" != "staging" ; then
      REACT_IMAGE_SUFFIX="-dev"
    fi
    REACT_APP_ENV_NAME="$(echo "$REF" | awk ' { $0=toupper(substr($0,1,1))substr($0,2); print } ')"
    ACME_SERVER_ENV_NAME="Let's Encrypt Staging Environment"
    FQDN="bxfinance-${REF}.ping-devops.com"
    ENV="-${REF}"
    PING_IDENTITY_DEVOPS_DNS_ZONE="bxfinance${ENV}.ping-devops.com"
    ## used for prefixing
    ;;
esac
K8S_NAMESPACE="bxfinance${ENV}" 

kubectl config set-context --current --namespace="${K8S_NAMESPACE}"

# PREP for helm
# VALUES_FILE=${VALUES_FILE:=iac/values.yaml}
# CHART_VERSION="0.3.9"
CURRENT_SHA=$(git log -n 1 --pretty=format:%h)

getGlobalVars() {
  kubectl get cm "global-env-vars" -o=jsonpath='{.data}' -n "${K8S_NAMESPACE}" | jq -r '. | to_entries | .[] | .key + "=" + .value + ""'
}

# getPfVars() {
# export PF_ADMIN_PUBLIC_HOSTNAME=$(kubectl get ing -l app.kubernetes.io/instance=${RELEASE},app.kubernetes.io/name=pingfederate-admin -o=jsonpath='{.items[0].spec.rules[0].host}')
# PING_IDENTITY_PASSWORD="2FederateM0re"
# }

createGlobalVarsPostman() {
  kubectl get cm "global-env-vars" -o=jsonpath='{.data}' -n "${K8S_NAMESPACE}" | jq -r '. | to_entries | .[] | .key + "=" + .value + ""'
  data=$(kubectl get cm "global-env-vars" -n "${K8S_NAMESPACE}" -o=jsonpath='{.data}')
  keys=$(echo "$data" | jq -r '. | to_entries | .[] | .key')
  varEntries=""
  for key in $keys ; do
    value=$(echo "${data}" | jq -r ".${key}" )
    varEntries="${varEntries} { \"key\": \"${key}\", \"value\": \"${value}\" },"
  done
  varEntries=${varEntries%?}
cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  global_postman_vars.json: |
    {
      "id": "eae83fc1-25de-4def-9062-7dc2ba993710",
      "name": "myping",
      "values": [
        ${varEntries}
      ],
      "_postman_variable_scope": "global"
    }
kind: ConfigMap
metadata:
  annotations:
    use-subpath: "true"
  name: global-env-vars-postman
  namespace: ${K8S_NAMESPACE}
EOF
}

# getPfClientAppInfo(){
#   # get bearer token (login). 
#   p1Token=$(curl -sS --location -u "${PF_ADMIN_WORKER_ID}:${PF_ADMIN_WORKER_SECRET}" --request POST "https://auth.pingone.com/${P1_ADMIN_ENV_ID}/as/token" \
#     --header 'Content-Type: application/x-www-form-urlencoded' \
#     --data-urlencode 'grant_type=client_credentials' | jq -r ".access_token")
#   # get client app and secret
#   pfEnvClientId=$(curl -sS --location --request GET "https://api.pingone.com/v1/environments/${P1_ADMIN_ENV_ID}/applications" \
#     --header "Authorization: Bearer ${p1Token}" \
#     | jq -r "._embedded.applications[] | select(.name==\"${RELEASE}-pf-admin\") | .id")
#   pfEnvClientSecret=$(curl -sS --location --request GET "https://api.pingone.com/v1/environments/${P1_ADMIN_ENV_ID}/applications/${pfEnvClientId}/secret" \
#     --header "Authorization: Bearer ${p1Token}" \
#     | jq -r '.secret')
# }