# Creating multicloud k8s cluster using terrafrom

## !! provision master node on top of aws cloud !!

## !! provision worker nodes on top of azure cloud !!

# steps to follow: 

### 1) Configure aws in your cli using "aws configure" command ( add secret key, access key, region and output type ).

### 2) set subscription_id = "" client_id = "" client_secret = "" tenant_id = "" for azurerm provider.

### 3) run "terraform init" command for downloading plugin.

### 4) run "terraform plan" command for creating execution plan.

### 5) run "terraform apply" command for running terraform code.

### 6) run "terraform destroy" command for destorying the infrastructure.
