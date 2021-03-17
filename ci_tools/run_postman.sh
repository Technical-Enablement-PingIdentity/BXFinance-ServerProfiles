#!/usr/bin/env sh

## Usage: ./run_postman.sh k8s_file.yaml
## filename must be equal to job name
# set -x
set -a 
# shellcheck source=./ci_tools.lib.sh
. ./ci_tools/ci_tools.lib.sh
set +a

# set -x

createGlobalVarsPostman

k8sFile="${1}"
JOB_NAME="${2}"
COLLECTION_ID="${3}"
export JOB_NAME COLLECTION_ID
test ! -f "${k8sFile}" && echo "${k8sFile} - file not found" && exit 1
envsubst < "${k8sFile}" > "${k8sFile}.final"
k8sFileFinal="${k8sFile}.final"

kubectl delete -f "${k8sFileFinal}" --ignore-not-found --force --grace-period=0 -n "${K8S_NAMESPACE}"

kubectl apply -f "${k8sFileFinal}" -n "${K8S_NAMESPACE}"

timeout=50
echo "waiting ${timeout}s for ${JOB_NAME} to complete "
while true ; do
  status="$(kubectl get job ${JOB_NAME} -o jsonpath='{.status.conditions[0].type}' --ignore-not-found -n ${K8S_NAMESPACE})"
  if test "${status}" = "Complete" -o "${status}" = "Failed" ; then
    break
  fi
  sleep 1
  timeout=$((timeout-1))
  test $timeout -le 1 && echo "JOB TIMED OUT" && break
done

kubectl logs "job/${JOB_NAME}" -n "${K8S_NAMESPACE}"

echo "Job Status: ${status}"
kubectl delete -f "${k8sFileFinal}" --ignore-not-found -n "${K8S_NAMESPACE}"
test "${status}" = "Complete" && exit 0