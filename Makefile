cluster=banshee

.PHONY: all init plan apply

all: create

init:
	cd terraform && \
	terraform init
 
plan: init
	cd terraform && \
	terraform plan -var="hcloud_token=${HCLOUD_TOKEN}" -var-file=tfvars/$(cluster).tfvars -out $(cluster).out

apply: $(cluster).out

$(cluster).out: plan
	cd terraform && \
	terraform apply $(cluster).out

$(cluster).json: $(cluster).out
	cd terraform && \
	terraform output -json > ../$(cluster).json

create: $(cluster).json
	kubeone apply --manifest cluster/$(cluster).yaml -t $(cluster).json	