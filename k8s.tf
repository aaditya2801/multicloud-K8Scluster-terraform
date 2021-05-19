// aws configure :

provider "aws" {
  region     = "ap-south-1"
}

provider "azurerm" {
   subscription_id = ""
   client_id = ""
   client_secret = ""
   tenant_id = ""
   features {}
}


resource "azurerm_resource_group" "myterraformgroup" {
    name     = "myResourceGroup_for_k8s"
    location = "eastus"

    tags = {
        environment = "k8s"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "myVnet_for_k8s"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    tags = {
        environment = "k8s vnet"
    }
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "mySubnet_for_k8s"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IP1
resource "azurerm_public_ip" "myterraformpublicip1" {
    name                         = "myPublicIP_for_k8s1"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.myterraformgroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "k8s ip1"
    }
}

# Create public IP2
resource "azurerm_public_ip" "myterraformpublicip2" {
    name                         = "myPublicIP_for_k8s2"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.myterraformgroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "k8s ip2"
    }
}
# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "myNetworkSecurityGroup_for_k8s"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "k8s_sg"
    }
}

# Create network interface1
resource "azurerm_network_interface" "myterraformnic1" {
    name                      = "myNIC1_for_k8s"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.myterraformgroup.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myterraformpublicip1.id
    }

    tags = {
        environment = "k8s_nic1"
    }
}

# Create network interface2
resource "azurerm_network_interface" "myterraformnic2" {
    name                      = "myNIC2_for_k8s"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.myterraformgroup.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myterraformpublicip2.id
    }

    tags = {
        environment = "k8s_nic2"
    }
}
# Connect the security group to the network interface1
resource "azurerm_network_interface_security_group_association" "example1" {
    network_interface_id      = azurerm_network_interface.myterraformnic1.id
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}
# Connect the security group to the network interface2
resource "azurerm_network_interface_security_group_association" "example2" {
    network_interface_id      = azurerm_network_interface.myterraformnic2.id
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}
# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myterraformgroup.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.myterraformgroup.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform sc"
    }
}

# Create (and display) an SSH key
resource "tls_private_key" "k8s_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { value = tls_private_key.k8s_ssh.private_key_pem }

# Create virtual machine1
resource "azurerm_linux_virtual_machine" "myterraformvm" {
    name                  = "k8s_worker_node1"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.myterraformnic1.id]
    size                  = "Standard_DS1_v2"
   
    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "RedHat"
        offer     = "RHEL"
        sku       = "8.2"
        version   = "latest"
    }

    computer_name  = "k8sworkernode1"
    admin_username = "azureuser"
    admin_password = "redHat123"
    disable_password_authentication = false

    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.k8s_ssh.public_key_openssh
    }
    connection {
        type = "ssh"
        user = "azureuser"
        host = azurerm_linux_virtual_machine.myterraformvm.public_ip_address 
        password = "redHat123"
        private_key = tls_private_key.k8s_ssh.private_key_pem
        agent = false
    }
    provisioner "remote-exec" {
       inline = [
        "wget https://raw.githubusercontent.com/aaditya2801/bash-script/main/docker.repo",
        "sudo mv docker.repo /etc/yum.repos.d/",
        "sudo yum install docker-ce --nobest -y",
        "sudo wget https://raw.githubusercontent.com/aaditya2801/k8s-ansible/main/master-node/files/kubernetes.repo",
        "sudo mv kubernetes.repo /etc/yum.repos.d/",
        "sudo yum install iproute-tc kubeadm -y", 
        "sudo systemctl enable docker --now",
        "sudo systemctl enable kubelet --now", 
        "sudo wget https://raw.githubusercontent.com/aaditya2801/k8s-ansible/main/master-node/files/daemon.json",
        "sudo mv daemon.json /etc/docker",
        "sudo systemctl restart docker",          
        "sudo wget https://raw.githubusercontent.com/aaditya2801/k8s-ansible/main/master-node/files/k8s.conf",
        "sudo mv k8s.conf /etc/sysctl.d/",
        "sudo sysctl --system",
    ]
    }
}

# Create virtual machine1
resource "azurerm_linux_virtual_machine" "myterraformvm2" {

depends_on = [
    azurerm_linux_virtual_machine.myterraformvm,
  ]

    name                  = "k8s_worker_node2"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.myterraformnic2.id]
    size                  = "Standard_DS1_v2"
   
    os_disk {
        name              = "myOsDisk2"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "RedHat"
        offer     = "RHEL"
        sku       = "8.2"
        version   = "latest"
    }

    computer_name  = "k8sworkernode2"
    admin_username = "azureuser"
    admin_password = "redHat123"
    disable_password_authentication = false

    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.k8s_ssh.public_key_openssh
    }
    connection {
        type = "ssh"
        user = "azureuser"
        host = azurerm_linux_virtual_machine.myterraformvm2.public_ip_address 
        password = "redHat123"
        private_key = tls_private_key.k8s_ssh.private_key_pem
        agent = false
    }
    provisioner "remote-exec" {
       inline = [
        "wget https://raw.githubusercontent.com/aaditya2801/bash-script/main/docker.repo",
        "sudo mv docker.repo /etc/yum.repos.d/",
        "sudo yum install docker-ce --nobest -y",
        "sudo wget https://raw.githubusercontent.com/aaditya2801/k8s-ansible/main/master-node/files/kubernetes.repo",
        "sudo mv kubernetes.repo /etc/yum.repos.d/",
        "sudo yum install iproute-tc kubeadm -y", 
        "sudo systemctl enable docker --now",
        "sudo systemctl enable kubelet --now", 
        "sudo wget https://raw.githubusercontent.com/aaditya2801/k8s-ansible/main/master-node/files/daemon.json",
        "sudo mv daemon.json /etc/docker",
        "sudo systemctl restart docker",          
        "sudo wget https://raw.githubusercontent.com/aaditya2801/k8s-ansible/main/master-node/files/k8s.conf",
        "sudo mv k8s.conf /etc/sysctl.d/",
        "sudo sysctl --system",
    ]
    }
}
resource "aws_vpc" "ownvpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "k8s_vpc"
  }
}
resource "aws_internet_gateway" "k8sgateway" {
  vpc_id = aws_vpc.ownvpc.id

  tags = {
    Name = "addy_gateway"
  }
}
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.ownvpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "k8s_subnet1"
  }
}
resource "aws_route_table" "my_table" {
  vpc_id = aws_vpc.ownvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8sgateway.id
  }

  tags = {
    Name = "k8s_routetable"
  }
}
resource "aws_route_table_association" "rta_subnet_public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.my_table.id
}

// RSA private key :

variable "EC2_Key" {default="k8s_key"}
resource "tls_private_key" "mynewkey_for_k8s" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

// AWS key-pair :

resource "aws_key_pair" "generated_key" {
  key_name   = var.EC2_Key
  public_key = tls_private_key.mynewkey_for_k8s.public_key_openssh
}

// security group :

resource "aws_security_group" "mysg" {

depends_on = [
    aws_key_pair.generated_key,
  ]

  name         = "allow_http_ssh"
  description  = "Allow http and ssh inbound traffic"
  vpc_id = aws_vpc.ownvpc.id
 
  ingress {
    description = "SSH Port"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } 
  ingress {
    description = "http from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  } 

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "security_for_k8s"
  }
}

// EC2 Instance and configuring k8s master node :

resource "aws_instance" "myterraformos1" {

depends_on = [
    aws_security_group.mysg,azurerm_linux_virtual_machine.myterraformvm2
  ]

  ami           = "ami-045e6fa7127ab1ac4"
  instance_type = "t2.micro"
  key_name      = var.EC2_Key
  associate_public_ip_address = true
  vpc_security_group_ids = [ "${aws_security_group.mysg.id}" ]
  subnet_id = aws_subnet.public.id
  availability_zone = "ap-south-1a"
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.mynewkey_for_k8s.private_key_pem
    host     = aws_instance.myterraformos1.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo wget https://raw.githubusercontent.com/aaditya2801/k8s-ansible/main/master-node/files/kubernetes.repo",
      "sudo mv kubernetes.repo /etc/yum.repos.d/",
      "sudo yum install iproute-tc docker kubeadm -y", 
      "sudo systemctl enable docker --now",
      "sudo systemctl enable kubelet --now", 
      "sudo kubeadm config images pull",
      "sudo wget https://raw.githubusercontent.com/aaditya2801/k8s-ansible/main/master-node/files/daemon.json",
      "sudo mv daemon.json /etc/docker",
      "sudo systemctl restart docker",          
      "sudo wget https://raw.githubusercontent.com/aaditya2801/k8s-ansible/main/master-node/files/k8s.conf",
      "sudo mv k8s.conf /etc/sysctl.d/",
      "sudo sysctl --system",
      "sudo kubeadm init --control-plane-endpoint ${aws_instance.myterraformos1.public_ip}:6443 --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=NumCPU --ignore-preflight-errors=MEM",
      "sudo mkdir -p $HOME/.kube",
      "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config",
      "sudo mv .kube /root/.",
      "sudo kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml",
      "sudo kubeadm token create --print-join-command > token.sh",
      "sudo chmod +x token.sh",
      "sudo kubectl get pods -n kube-system",
      "sudo kubectl get nodes",
      "sudo amazon-linux-extras install epel -y",
      "sudo yum install sshpass -y",
      "sudo sshpass -p redHat123 scp -o StrictHostKeyChecking=no ./token.sh azureuser@${azurerm_linux_virtual_machine.myterraformvm.public_ip_address}:/home/azureuser/",
      "sudo sshpass -p redHat123 scp -o StrictHostKeyChecking=no ./token.sh azureuser@${azurerm_linux_virtual_machine.myterraformvm2.public_ip_address}:/home/azureuser/",
      "sudo sshpass -p redHat123 ssh -o StrictHostKeyChecking=no  azureuser@${azurerm_linux_virtual_machine.myterraformvm.public_ip_address} sudo ./token.sh",
      "sudo sshpass -p redHat123 ssh -o StrictHostKeyChecking=no  azureuser@${azurerm_linux_virtual_machine.myterraformvm2.public_ip_address} sudo ./token.sh"
    ]
  }

  tags = {
    Name = "k8s_masternode"
  }
}

