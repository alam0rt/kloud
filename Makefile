cluster=banshee

.PHONY: all init plan apply kapply output

all: create

init:
	cd terraform && \
	terraform init
 
plan: init
	cd terraform && \
	terraform plan -var="hcloud_token=${HCLOUD_TOKEN}" -var-file=tfvars/$(cluster).tfvars -out $(cluster).out

apply: $(cluster).out

output: apply
	cd terraform && \
	terraform output -json > ../cluster/$(cluster).json


kapply: $(cluster).tar.gz

$(cluster).out: plan
	cd terraform && \
	terraform apply $(cluster).out

$(cluster).json: output

$(cluster).tar.gz: $(cluster).json
	./kubeone apply --manifest cluster/$(cluster).yaml -t cluster/$(cluster).json --backup cluster/$(cluster).tar.gz --force-upgrade