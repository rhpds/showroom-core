#!/usr/bin/env bash

# content-only
echo "Generating VM config for content-only example"
helm template ../helm -f ./content-only/values.yaml > ./content-only/vm-example.yaml

echo "Generating OCP config for content-only example"
helm template ../helm --set deployer.target=openshift -f ./content-only/values.yaml > ./content-only/ocp-example.yaml

# split-content-terminals
echo "Generating VM config for split-content-terminals example"
helm template ../helm -f ./split-content-terminals/values.yaml > ./split-content-terminals/vm-example.yaml

echo "Generating OCP config for split-content-terminals example"
helm template ../helm --set deployer.target=openshift -f ./split-content-terminals/values.yaml > ./split-content-terminals/ocp-example.yaml

# all-services
echo "Generating VM config for all-services example"
helm template ../helm -f ./all-services/values.yaml > ./all-services/vm-example.yaml

echo "Generating OCP config for all-services example"
helm template ../helm --set deployer.target=openshift -f ./all-services/values.yaml > ./all-services/ocp-example.yaml

# vm-with-ttyd-sshd
echo "Generating VM config for all-services example"
helm template ../helm -f ./vm-with-ttyd-sshd/values.yaml > ./all-services/vm-example.yaml