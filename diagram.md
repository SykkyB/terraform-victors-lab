# Infrastructure Diagram

This diagram is generated automatically from Terraform state using InfraMap.

---

## How to generate diagram

```bash
terraform init
terraform plan -out=tfplan
terraform state pull > terraform.tfstate
ls -lh terraform.tfstate
inframap generate terraform.tfstate | dot -Tpng > diagram.png
