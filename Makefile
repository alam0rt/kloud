cluster=banshee

all: plan

init:
	@cd terraform
	terraform init
	@cd ..
 
plan: init
	cd terraform && \
	terraform plan -var-file=tfvars/$(cluster).tfvars -out $(cluster).out

apply: plan
	cd terraform && \
	terraform apply -var-file=tfvars/$(cluster).tfvars -in $(cluster).out