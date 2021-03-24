#!/usr/bin/env sh

set -x
# set -e

set -a
# shellcheck source=./ci_tools.lib.sh
. ./ci_tools/ci_tools.lib.sh

## builds sha for each product based on the folder name in ./profiles/* (e.g. pingfederateSha)
  ## this determines what will be redeployed. 
for D in ./profiles/* ; do 
  if [ -d "${D}" ]; then 
    _prodName=$(basename "${D}")
    dirr="${D}"
    eval "${_prodName}Sha=$(git log -n 1 --pretty=format:%h -- "$dirr")"
  fi
done

export pingdirectorySha pingfederateSha pingdatagovernanceSha pingdatagovernancepapSha pingaccessSha
export REF

k8sFolder="k8s${ENV:+-feature}"
kustomize build "${k8sFolder}" | envsubst
if test "${1}" != "--dry-run" ; then
  kustomize build "${k8sFolder}" | envsubst | kubectl apply -n ${K8S_NAMESPACE} -f -
  echo "waiting for all containers to be healthy"
  _timeout=100
  _attempt=0
  while test ${_attempt} -lt ${_timeout} ; do
    sleep 6
    if test $(kubectl get pods -o go-template='{{range $index, $element := .items}}{{range .status.containerStatuses}}{{if not .ready}}{{$element.metadata.name}}{{"\n"}}{{end}}{{end}}{{end}}' | wc -l ) = 0 ; then
        break;
    fi
    _attempt=$((_attempt+1))
  done
else
  echo "dry-run, not deploying"
fi