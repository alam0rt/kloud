cluster=banshee

all: plan

init:
	cd terraform && \
	terraform init
 
plan: init
	cd terraform && \
	terraform plan -var-file=tfvars/$(cluster).tfvars -out ../$(cluster).out

apply: plan
	cd terraform && \
	terraform apply ../$(cluster).out

output: apply
	cd terraform && \
	terraform output -json > ../$(cluster).json