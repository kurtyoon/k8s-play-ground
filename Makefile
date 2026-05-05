TOFU ?= tofu
OCI_DIR := infra/oci/tofu
ANSIBLE_DIR := ansible
KUBECONFIG_OUT := $(HOME)/.kube/oci-k3s.yaml

.PHONY: oci-check infra-init infra-plan infra-apply infra-destroy inventory \
        ansible-ping k3s-install kubeconfig argocd-bootstrap oci-sync \
        local-up local-down

# OCI
oci-check:
	./infra/oci/scripts/oci-check.sh

infra-init:
	cd $(OCI_DIR) && $(TOFU) init

infra-plan:
	cd $(OCI_DIR) && $(TOFU) plan

infra-apply:
	cd $(OCI_DIR) && $(TOFU) apply

infra-destroy:
	cd $(OCI_DIR) && $(TOFU) destroy

inventory:
	cd $(OCI_DIR) && $(TOFU) output -json > ../oci-outputs.json
	./infra/oci/scripts/render-inventory.sh

# Ansible
ansible-ping:
	ansible -i $(ANSIBLE_DIR)/inventory/oci.ini all -m ping

k3s-install:
	ansible-playbook -i $(ANSIBLE_DIR)/inventory/oci.ini $(ANSIBLE_DIR)/playbooks/site.yaml

kubeconfig:
	ansible-playbook -i $(ANSIBLE_DIR)/inventory/oci.ini $(ANSIBLE_DIR)/playbooks/30-fetch-kubeconfig.yaml

argocd-bootstrap:
	ansible-playbook -i $(ANSIBLE_DIR)/inventory/oci.ini $(ANSIBLE_DIR)/playbooks/40-bootstrap-argocd.yaml

# GitOps
oci-sync:
	KUBECONFIG=$(KUBECONFIG_OUT) kubectl apply -f clusters/oci-prod/root-app.yaml

# Local
local-up:
	./bootstrap/local-colima/start.sh

local-down:
	./bootstrap/local-colima/stop.sh
