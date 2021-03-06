
#                        *** AWS 3 Tier Application Project Using Terraform ***

====================================================================================

## 001. Create aws-terraform project folder and configure backend.

- Configure <root/backend.tf> file to store terraform state metadata and lock the state file for teamwork.

```
terraform {
  cloud {
    organization = "uzbek"

    workspaces {
      name = "devops"
    }
  }
}
```

- Enter command <terraform login> in the cli to request API token in terraform cloud.
- Press the link on cli and give a name for token. Copy the generated API token and paste in the cli.
- Initialize by passing the command <terraform init>. In terraform cloud, go to <Settings> - <General> and choose <Local> option so plan and apply occur on local machine.

====================================================================================

## 002. Configure AWS provider.

- Create <root/providers.tf file>

```
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.aws_region     # passed region variable name from <root/variables.tf> file.
}
```

- Create <root/variables.tf> file.


This Region value will be referenced in <root/providers.tf> file.
```
variable "aws_region" {
  default = "us-east-1"       # passed region variable in <root/providers.tf> file.
}
```

- Run <terraform init> to download plugins and initialize the provider.

====================================================================================

## 003. Create VPC resource.

- Create <root/networking> module folder.
- Inside networking folder create <main.tf>, <outputs.tf> and <variables.tf> files.
- In <root/networking/main.tf> file create VPC resources.

This resource creates random integer which allows to assign new random number to VPC.
```
resource "random_integer" "random" {
  min = 1           # Assigns the lowest number.
  max = 100         # Assigns the highest number.
}

# This resource creates AWS VPC.

resource "aws_vpc" "mtc_vpc" {
  cidr_block           = var.vpc_cidr   # CIDR is referenced from <networking/variables.tf> file.
  enable_dns_hostnames = true           # Must enable dns hostname and support to provide hostname.
  enable_dns_support   = true

  # This tags name is going to be passed to AWS.
  
  tags = {
    Name = "mtc_vpc-${random_integer.random.id}"   # Referenced random integer resource to assign random integer ID.
  }

  # This lifecycle policy will force vpc destruction until new VPC is created so IGW can associate with first.
    Otherwise, if VPC is destroyed first, for IGW there is no VPC to associate with, so "terraform destroy" will time out.
  }
  lifecycle {
    create_before_destroy = true
  }
}
```

- Configure the values in <networking/variables.tf> file which references in <networking/main.tf> file.

```
# This variable being referenced in VPC resource in <networking/main.tf>

variable "vpc_cidr" {   # Referenced from "vpc_cidr" in <root/main.tf>, <networking/main.tf, variables.tf> files.
  type = string
}

variable "access_ip" {  # Referenced from <root/mainl.tf>, <networking/main.tf, variables.tf> files and passed to security group resources.
  type = string
}
```

- Configure <networking/outputs.tf> file so that <root/main.tf> can consume VPC outputs from <networking/main.tf> to create VPC
  and pass them on to other modules.


This out will be consumed by <root/main.tf> VPC module block to create VPC.
```
output "vpc_id" {
  value = aws_vpc.mtc_vpc.id
}
```

- In <root/main.tf> file create module and reference VPC resource from <networking/main.tf> file.

```
# Deploys <networking/main.tf> resources.

module "networking" {
  source   = "./networking"   # Referencing to <root/networking> module
  vpc_cidr = "10.123.0.0/16"  # This value goes to <networking/variables.tf> then <networking/main.tf> which is <var.vpc_cidr>
}
```

- Run <terraform fmt -recursive> to format and clean the code.
- Run <terraform init> to initialize plugins and new resources.
- Run <terraform validate> to validate the code.
- Run <terraform plan> to see which resources will be created.
- Run <terraform apply --auto-approve> to deploy the resources.

====================================================================================

## 004. Create Public and Private Subnets and CIDR blocks.


- In <root/main.tf> file update "networking" module to reference "networking" module.

```
# Deploy Networking Resources

module "networking" {
  source           = "./networking"
  vpc_cidr         = local.vpc_cidr   # Referenced from "locals" block above.
  private_sn_count = 3    # Creates 3 private subnets of odd numbers: 10.123.1.0/24, 10.123.3.0/24, 10.123.5.0/24
  public_sn_count  = 2    # Creates 2 public subnets of even numbers: 10.123.2.0/24, 10.123.4.0/24
  max_subnets      = 20   # Creates needed subnets. Referenced from <networking.variables.tf> file.
  private_cidrs    = [for i in range(1, 255, 2) : cidrsubnet(local.vpc_cidr, 8, i)]   # cidr_block referenced from "locals" block above.
  public_cidrs     = [for i in range(2, 255, 2) : cidrsubnet(local.vpc_cidr, 8, i)]   # cidr_block referenced from "locals" block above.
  max_subnets      = 20
  access_ip        = var.access_ip    # referenced from <networking.main.tf, variables.tf> files.
  security_groups  = local.security_groups  # Referenced from <root/locals.tf> file.
  db_subnet_group  = false    # Referenced from <networking/main.tf, variables.tf> which determines to deploy subnet group or not. 
}
```
I used for loop with cidrsubnet function and range method which calculates a subnet addresses within assigns dynamic range of IP address prefixes.
Example of assigning IP addresses dynamically: 
On the CLI type "terraform console" and pass the for loop function: [for i in range(1, 255, 2) : cidrsubnet("10.123.0.0/16", 8, i)]
For private_cidrs, for index of in range of 1 to 255 steps over by 2 and calculates from cidrsubnet of 10.123.0.0/16, increment to 8
which would be /24 and increase it by 1 which gives result of 10.123.1.0/24.
For public_cidrs, for index of in range of 2 to 255 steps over by 2 and calculates from cidrsubnet of 10.123.0.0/16, increment to 8
which would be /24 and increase it by 1 which gives result of 10.123.1.0/24.


- Once finished updating module "networking" in <root/main.tf>, reference them in <networking/variables.tf> file.


Created these variables in <networking/variables.tf> and referenced to module "networking" block in <root/main.tf, locals.tf> files.
```
variable "vpc_cidr" {}
variable "public_cidrs" {}
variable "private_cidrs" {}
variable "public_sn_count" {}
variable "private_sn_count" {}
variable "max_subnets" {}
variable "access_ip" {}
variable "security_groups" {}
variable "db_subnet_group" {}
```

- Next create data source for AZ, public and private aws_subnet resource in <networking/main.tf> file.


This data source enables to assign random Availability zone for each subnet which mitigates running out of AZs.
```
data "aws_availability_zones" "available" {}  # Referenced in aws_subnet resource.
```

- Create random_shuffle resource to randomly shuffle AZs and assign subnet to each shuffled AZs so I don't run out of AZs.

```
resource "random_shuffle" "public_az" {
  input        = data.aws_availability_zones.available.names    # Referenced to AZ data source above.
  result_count = var.max_subnets    # Referenced to max_subnets in <networking/variables.tf>
}

# This resource creates public Subnets.

resource "aws_subnet" "mtc_public_subnet" {
  count                   = var.public_sn_count   # Referenced from <root/main.tf> "networking" module and variables.tf file.
  vpc_id                  = aws_vpc.mtc_vpc.id    # Referenced from <root/main.tf> "networking" module and variables.tf file.
  cidr_block              = var.public_cidrs[count.index] # Pulls the cidr blocks one by one and assigns to each subnet.
  map_public_ip_on_launch = true                  # Automatically maps public IP to public subnet on launch.
  availability_zone       = random_shuffle.public_az.result[count.index]  # Referenced from random_shuffle resource above.

  tags = {
    Name = "mtc_public_${count.index + 1}"
  }
}

# This resource creates private Subnets.

resource "aws_subnet" "mtc_private_subnet" {
  count                   = var.private_sn_count  # Referenced from <root/main.tf> "networking" module and variables.tf file.
  vpc_id                  = aws_vpc.mtc_vpc.id    # Referenced from <root/main.tf> "networking" module and variables.tf file.
  cidr_block              = var.private_cidrs[count.index]  # Pulls the cidr blocks one by one and assigns to each subnet.
  map_public_ip_on_launch = false                 # Doesn't map public IP on launch thus it becomes private subnet.
  availability_zone       = random_shuffle.public_az.result[count.index]  # Referenced from random_shuffle resource above.

  tags = {
    Name = "mtc_private_${count.index + 1}"
  }
}
```

- Run <terraform fmt -recursive> to format and clean the code.
- Run <terraform init> to initialize plugins and new resources.
- Run <terraform validate> to validate the code.
- Run <terraform plan> to see which resources will be created.
- Run <terraform apply --auto-approve> to deploy the resources.
- Run <terraform destroy --auto-approve> to destroy the resources.

====================================================================================

## 005. Create Route Tables and The Internet Gateway.

- Create aws_internet_gateway resource in <networking/main.tf> file.

```
resource "aws_internet_gateway" "mtc_internet_gateway" {
  vpc_id = aws_vpc.mtc_vpc.id

  tags = {
    Name = "mtc_igw"
  }
}
```

- Create public "aws_route_table" in <networking/main.tf> file.

```
resource "aws_route_table" "mtc_public_rt" {
  vpc_id = aws_vpc.mtc_vpc.id

  tags = {
    Name = "mtc_public"
  }
}
```

- Create default public "aws_route" in <networking/main.tf> file to auto assign to default route if no public route table explicitly specified.

```
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.mtc_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.mtc_internet_gateway.id
}
```

- Create private "aws_default_route_table" in <networking/main.tf> file to auto assign private route tables if there is no explicit route table is specified.

```
resource "aws_default_route_table" "mtc_private_rt" {
  default_route_table_id = aws_vpc.mtc_vpc.default_route_table_id

  tags = {
    Name = "mtc_private"
  }
}
```

- Create "aws_route_table_association" in <networking/main.tf> file to associate public RTs with public subnets.

```
resource "aws_route_table_association" "mtc_public_assoc" {
  count          = var.public_sn_count  # Referenced from <root/main.tf> "networking" module, and <networking/variables.tf> file.
  subnet_id      = aws_subnet.mtc_public_subnet.*.id[count.index] # Referenced "aws_subnet" resource above. ".*.id[count.index]" all subnets.
  route_table_id = aws_route_table.mtc_public_rt.id
}
```

- Run <terraform fmt -recursive> to format and clean the code.
- Run <terraform init> to initialize plugins and new resources.
- Run <terraform validate> to validate the code.
- Run <terraform plan> to see which resources will be created.
- Run <terraform apply --auto-approve> to deploy the resources.
- Run <terraform destroy --auto-approve> to destroy the resources.

====================================================================================

## 006. Create VPC Security Groups.

- First create <root/locals.tf> file and pass the following blocks so that I don't have to repeat and have value in one place and reference elsewhere.

```
locals {
  vpc_cidr = "10.123.0.0/16"  # Referenced to "vpc_cidr", "private_cidrs" and "public_cidrs" below.
}
```

This "locals" block wil be dynamically  referenced in <networking.main.tf>
```
locals {
  security_groups = {
    public = {
      name        = "public_sg"
      description = "public access"
      ingress = {
        ssh = {
          from        = 22
          to          = 22
          protocol    = "tcp"
          cidr_blocks = [var.access_ip]
        }
        http = {
          from        = 80
          to          = 80
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
    rds = {
      name        = "rds_sg"
      description = "rds access"
      ingress = {
        mysql = {
          from        = 3306
          to          = 3306
          protocol    = "tcp"
          cidr_blocks = [local.vpc_cidr]
        }
      }
    }
  }
}
```
This "access_ip" is passed from <root/terraform.tfvars> to <root/variables.tf> to <root/main.tf> to <networking/variables.tf> and finally "access_ip" is specified in <networking/main.tf> of "aws_security_group" resource at "cidr_blocks = [var.access_ip]"


- Create "aws_security_group" resource in <networking.main.tf> file.


This resource creates public Security Group. It's referenced from <root/locals.tf> file.
```
resource "aws_security_group" "mtc_sg" {
  for_each    = var.security_groups
  name        = each.value.name
  description = each.value.description
  vpc_id      = aws_vpc.mtc_vpc.id

  # Public Security Group

  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"    # Value "-1" means all protocols.
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

- In <networking/validates.tf> file create variable for "access_ip" to reference "cidr_blocks" in "dynamic ingress" of Public Security Group. And also reference in <root/main.tf> and <root/terraform.tfvars> files which I have alreadyresourced above.
- Create <root/terraform.tfvars> file to store credentials such as IP addresses. This file must be included in .gitignore file.

```
access_ip = "0.0.0.0/0"
```
This "access_ip" is passed from <root/terraform.tfvars> to <root/variables.tf> to <root/main.tf> to <networking/variables.tf> and finally "access_ip" is specified in <networking/main.tf> of "aws_security_group" resource at "cidr_blocks = [var.access_ip]"


- VPC RDS Subnet Group and Conditionals which dictates the pull of subnets for RDS instances.


This resource creates "aws_db_subnet_group" 
```
resource "aws_db_subnet_group" "mtc_rds_subnetgroup" {
  count      = var.db_subnet_group == "true" ? 1 : 0    # Determines to deploy subnet group or not.
  name       = "mtc_rds_subnetgroup"
  subnet_ids = aws_subnet.mtc_private_subnet.*.id
  tags = {
    Name = "mtc_rds_sng"
  }
}
```


- Run <terraform fmt -recursive> to format and clean the code.
- Run <terraform init> to initialize plugins and new resources.
- Run <terraform validate> to validate the code.
- Run <terraform plan> to see which resources will be created.
- Run <terraform apply --auto-approve> to deploy the resources.
- Run <terraform destroy --auto-approve> to destroy the resources.

====================================================================================

## 007. RDS set up.

- Create <root/database> folder and create <database/main.tf, variables.tf> files.
- a. In <database/main.tf> file create the "aws_db_instance" resource.


# --- database/main.tf ---
```
resource "aws_db_instance" "mtc_db" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  name                   = var.dbname
  username               = var.dbuser
  password               = var.dbpassword
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids
  identifier             = var.db_identifier
  skip_final_snapshot    = var.skip_db_snapshot
  tags = {
    Name = "mtc-db"
  }
}
```

- b. In <database/variables.tf> file reference parameters from module "database" in <root/main.tf> file.


# --- database/variables.tf ---
```
variable "db_instance_class" {}
variable "dbname" {}
variable "dbuser" {}
variable "dbpassword" {}
variable "vpc_security_group_ids" {}
variable "db_subnet_group_name" {}
variable "db_engine_version" {}
variable "db_identifier" {}
variable "skip_db_snapshot" {}
```

- c. In <root/main.tf> file create "database" module and configure key value parameters to reference in <database/variables.tf> file.


# --- root/main.tf ---
```
module "database" {
  source                 = "./database"
  db_engine_version      = "5.7.22"
  db_instance_class      = "db.t2.micro"
  dbname                 = var.dbname
  dbuser                 = var.dbuser
  dbpassword             = var.dbpassword
  db_identifier          = "mtc-db"
  skip_db_snapshot       = true
  db_subnet_group_name   = module.networking.db_subnet_group_name[0]
  vpc_security_group_ids = module.networking.db_security_group
}
```

- d. In <root/terraform.tfvars> file configure sensitive data to reference in <root/main.tf> "database" module.

```
# --- root/terraform.tfvars ---
access_ip = "0.0.0.0/0"

# --db vars --
dbname     = "rancher"
dbuser     = "bobby"
dbpassword = "s00p3rS3cr3t"
```

- e. In <root/variables.tf> file configure variables to reference in <root/main.tf> file.

```
# --- root/variables.tf ---

# --------aws providers region variable

variable "aws_region" {
  default = "us-west-2"
}

variable "access_ip" {}

# -------variables for database

variable "dbname" {
  type = string
}
variable "dbuser" {
  type = string
}
variable "dbpassword" {
  type      = string
  sensitive = true
}
```

- f. In <networking/variables.tf> file configure outputs so "database" module can access outputs for "db_subnet_group_name" and "db_security_group".

```
 # --- networking/outputs.tf ---

output "vpc_id" {
  value = aws_vpc.mtc_vpc.id
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.mtc_rds_subnetgroup.*.name
}

output "db_security_group" {
  value = aws_security_group.mtc_sg["rds"].id
}

output "public_sg" {
  value = aws_security_group.mtc_sg["public"].id
}

output "public_subnets" {
  value = aws_subnet.mtc_public_subnet.*.id
}
```

- Run <terraform fmt -recursive> to format and clean the code.
- Run <terraform init> to initialize plugins and new resources.
- Run <terraform validate> to validate the code.
- Run <terraform plan> to see which resources will be created.
- Run <terraform apply --auto-approve> to deploy the resources.
- Run <terraform destroy --auto-approve> to destroy the resources.

====================================================================================

## 008. ALB (Application Load Balancer) Set Up.

- Create <root/loadbalancing> module folder and create <loadbalancing/main.tf, variables.tf, outputs.tf> files.
- a. In <loadbalancing/main.tf> file create "aws_lb", "aws_lb_target_group" and "aws_lb_listener" resources.

```
# --- loadbalancing/main.tf ---

resource "aws_lb" "mtc_lb" {
  name            = "mtc-loadbalancer"
  subnets         = var.public_subnets
  security_groups = [var.public_sg]
  idle_timeout    = 400
}

resource "aws_lb_target_group" "mtc_tg" {
  name     = "mtc-lb-tg-${substr(uuid(), 0, 3)}" # uuid() - generates random ID and substr() - func gets subtracts it.
  port     = var.tg_port
  protocol = var.tg_protocol
  vpc_id   = var.vpc_id

  lifecycle {
    create_before_destroy = true    # This will make sure to create new target group before destroying so listener can be attached.
    ignore_changes        = [name]  # This will make sure the is not changed.
  }

  health_check {
    healthy_threshold   = var.elb_healthy_threshold
    unhealthy_threshold = var.elb_unhealthy_threshold
    timeout             = var.elb_timeout
    interval            = var.elb_interval
  }
}

resource "aws_lb_listener" "mtc_lb_listener" {
  load_balancer_arn = aws_lb.mtc_lb.arn   # This value gets the ARN ALB's ARN and attaches it to the listener.
  port              = var.listener_port
  protocol          = var.listener_protocol
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mtc_tg.arn   # This value retrieves the target group ARN and attaches to the listener.
  }
}
```

- b. In <loadbalancing/variables.tf> file create variables for referencing.

```
# --- loadbalancing/variables.tf ---

variable "public_sg" {}
variable "public_subnets" {}
variable "tg_port" {}
variable "tg_protocol" {}
variable "vpc_id" {}
variable "elb_healthy_threshold" {}
variable "elb_unhealthy_threshold" {}
variable "elb_timeout" {}
variable "elb_interval" {}
variable "listener_port" {}
variable "listener_protocol" {}
```

- c. In <networking/outputs.tf> file configure "public_sg" and "public_subnets" outputs so <root/main.tf> "loadbalancing" module can access and pull them from <networking/outputs.tf>. file.

```
# --- networking/outputs.tf ---

output "vpc_id" {
  value = aws_vpc.mtc_vpc.id
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.mtc_rds_subnetgroup.*.name
}

output "db_security_group" {
  value = aws_security_group.mtc_sg["rds"].id
}

output "public_sg" {
  value = aws_security_group.mtc_sg["public"].id
}

output "public_subnets" {
  value = aws_subnet.mtc_public_subnet.*.id
}
```

- d. In <root/main.tf> file configure "loadbalancing" module.

```
module "loadbalancing" {
  source                  = "./loadbalancing"
  public_sg               = module.networking.public_sg       # Referenced from <networking.outputs.tf> file.
  public_subnets          = module.networking.public_subnets  # Referenced from <networking.outputs.tf> file.
  tg_port                 = 8000
  tg_protocol             = "HTTP"
  vpc_id                  = module.networking.vpc_id
  elb_healthy_threshold   = 2
  elb_unhealthy_threshold = 2
  elb_timeout             = 3
  elb_interval            = 30
  listener_port           = 80
  listener_protocol       = "HTTP"
}
```

- e. In <loadbalancing/outputs.tf> file add outputs for ALB target group ARN to be consumed by <root/main.tf> and <compute/variables.tf> files.

```
output "lb_target_group_arn" {
  value = aws_lb_target_group.mtc_tg.arn
}

# This output gives the ALB DNS name URL to access our NGINX running in k3s clusters.

output "lb_endpoint" {
  value = aws_lb.mtc_lb.dns_name
}
```

- f. Create <root/outputs.tf> file and add reference to outputs "load_balancer_endpoint", "instances", "kubeconfig" and "k3s" outputs.
```
# --- root/loadbalancing/outputs.tf ---

# This output spits out the ALB DNS name URL which we can access our NGINX deployment running in k3s clusters.

output "load_balancer_endpoint" {
  value = module.loadbalancing.lb_endpoint
}

# This output exposes the public IP addresses of our instances.

# output "instances" {
#   value = {for i in module.compute.instance : i.tags.Name =>  "${i.public_ip}:${module.compute.instance_port}"}
#   sensitive = true
# }


output "kubeconfig" {
  value     = [for i in module.compute.instance : "export KUBECONFIG=../k3s-${i.tags.Name}.yaml"]
  sensitive = true
}

output "k3s" {
  value     = [for i in module.compute.instance : "../k3s-${i.tags.Name}.yaml"][0]
  sensitive = true
}
```

- Run <terraform fmt -recursive> to format and clean the code.
- Run <terraform init> to initialize plugins and new resources.
- Run <terraform validate> to validate the code.
- Run <terraform plan> to see which resources will be created.
- Run <terraform apply --auto-approve> to deploy the resources.
- Run <terraform destroy --auto-approve> to destroy the resources.

====================================================================================

## 009. Create and Deploy EC2 instances.

- Create <root/compute> folder and <compute/main.tf, variables.tf and outputs.tf> files.
- a. In <compute/main.tf> file create "aws_ami" data block, "random_id", "aws_key_pair", "aws_instance", and "aws_lb_target_group_attachment" resources.

```
# --- compute/main.tf ---

data "aws_ami" "server_ami" {
  most_recent = true

  owners = ["099720109477"]

  # This filter block will filter out the latest AMI for the instance.
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"] # date is replaced vs "*" to get latest AMI.
  }
}

resource "random_id" "mtc_node_id" {
  byte_length = 2
  count       = var.instance_count

  # This keepers block generates different random ID when the resource is changed.
  
  keepers = {
    key_name = var.key_name
  }
}

resource "aws_key_pair" "mtc_auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)  # file func extracts contents of any file, in our case public ssh key.
}

resource "aws_instance" "mtc_node" {
  count         = var.instance_count
  instance_type = var.instance_type
  ami           = data.aws_ami.server_ami.id

  tags = {
    Name = "mtc_node-${random_id.mtc_node_id[count.index].dec}"
  }

  key_name               = aws_key_pair.mtc_auth.id
  vpc_security_group_ids = [var.public_sg]
  subnet_id              = var.public_subnets[count.index]
  user_data = templatefile(var.user_data_path,
    {
      nodename    = "mtc-${random_id.mtc_node_id[count.index].dec}"
      db_endpoint = var.db_endpoint
      dbuser      = var.dbuser
      dbpass      = var.dbpassword
      dbname      = var.dbname
    }
  )


  root_block_device {
    volume_size = var.vol_size
  }

  # This provisioner accesses the remote EC2 instance and runs the delay.sh script which checks and verifies
    that scp_script.tpl file exists to run, if not then it will wait until scp_script.tpl file is created and runs it.

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.public_ip
      private_key = file(var.private_key_path)  # file func will extract the contents of any file.
    }
    script = "${path.root}/delay.sh"
  }
  provisioner "local-exec" {
    command = templatefile("${path.cwd}/scp_script.tpl",
      {
        nodeip           = self.public_ip
        k3s_path         = "${path.cwd}/../"
        nodename         = self.tags.Name
        private_key_path = var.private_key_path
      }
    )
  }

  # Executes the command locally and when terraform destroy applied local-exec will delete k3s-mtc_node-* file.
  
  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.cwd}/../k3s-mtc_node-*"
  }
}

# This resource adds our EC2 instances to the target group.
resource "aws_lb_target_group_attachment" "mtc_tg_attach" {
  count            = var.instance_count
  target_group_arn = var.lb_target_group_arn
  target_id        = aws_instance.mtc_node[count.index].id
  port             = var.tg_port
}
```

- b. In <compute/variables.tf> file create variables to reference in <compute/main.tf> file.

```
# --- compute/variables.tf ---

variable "instance_count" {}
variable "instance_type" {}
variable "public_sg" {}
variable "public_subnets" {}
variable "vol_size" {}
variable "public_key_path" {}
variable "key_name" {}
variable "dbuser" {}
variable "dbname" {}
variable "dbpassword" {}
variable "db_endpoint" {}
variable "user_data_path" {}
variable "lb_target_group_arn" {}
variable "private_key_path" {}
variable "tg_port" {}
```

- c. In <compute/outputs.tf> file create an output for the "instance" resource so <root/main.tf> "compute" module can reference and access it.

```
output "instance" {
  value     = aws_instance.mtc_node[*]
  sensitive = true
}
```

- d. In <root/main.tf> file create "compute" module to reference <root/compute> module and create EC2 instance.

```
module "compute" {
  source              = "./compute"
  public_sg           = module.networking.public_sg
  public_subnets      = module.networking.public_subnets
  instance_count      = 1
  instance_type       = "t3.micro"
  vol_size            = "20"
  public_key_path     = "/home/ubuntu/.ssh/mtckey.pub"
  key_name            = "mtckey"
  dbname              = var.dbname
  dbuser              = var.dbuser
  dbpassword          = var.dbpassword
  db_endpoint         = module.database.db_endpoint
  user_data_path      = "${path.root}/userdata.tpl"
  lb_target_group_arn = module.loadbalancing.lb_target_group_arn
  tg_port             = 8000
  private_key_path    = "/home/ubuntu/.ssh/mtckey"
}
```

- e. In <root/locals.tf> file add security group rule for nginx and open ports for 8000.

```
locals {
  vpc_cidr = "10.123.0.0/16"
}

locals {
  security_groups = {
    public = {
      name        = "public_sg"
      description = "public access"
      ingress = {
        open = {
          from        = 0
          to          = 0
          protocol    = -1
          cidr_blocks = [var.access_ip]
        }
        tg = {
          from        = 8000
          to          = 8000
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
        http = {
          from        = 80
          to          = 80
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
        nginx = {
          from        = 8000
          to          = 8000
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
    rds = {
      name        = "rds_sg"
      description = "rds access"
      ingress = {
        mysql = {
          from        = 3306
          to          = 3306
          protocol    = "tcp"
          cidr_blocks = [local.vpc_cidr]
        }
      }
    }
  }
}
```

- f. In <database/outputs.tf> file create "db_endpoint" output which will be consumed by <root/main.tf> "compute" module.

```
# --- database/outputs.tf ---

output "db_endpoint" {
  value = aws_db_instance.mtc_db.endpoint
}
```

- g. In <root> create userdata.tpl file which will hold data to run while deploying the k3s clusters.

```
#!/bin/bash
sudo hostnamectl set-hostname ${nodename} &&
curl -sfL https://get.k3s.io | sh -s - server \
--datastore-endpoint="mysql://${dbuser}:${dbpass}@tcp(${db_endpoint})/${dbname}" \
--write-kubeconfig-mode 644 \
--tls-san=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
```

- Run <terraform fmt -recursive> to format and clean the code.
- Run <terraform init> to initialize plugins and new resources.
- Run <terraform validate> to validate the code.
- Run <terraform plan> to see which resources will be created.
- Run <terraform apply --auto-approve> to deploy the resources.
- Run <terraform destroy --auto-approve> to destroy the resources.


- h. Connection to our k3s cluster. Copy the public IP address of our mtc_node-12345 cluster.
```
ssh -i ~/.ssh/ubuntu/keymtc ubuntu@**.***.***.**  # Paste the public IP address. 
kubectl get nodes
```

- i. Inside the k3s cluster create the NGINX deployment.
```
vim deployment.yaml
:set paste  # Inside deployment.yaml file press ":set paste" to make sure that there is no any issues with indentation once pasted.
```
Paste the code inside deployment.yaml file.
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec :
  replicas: 2
  selector:
    matchLabels:
      # manage pods with the label app: nginx
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
          hostPort: 8000
```
Then type <:wq!> to save the file.
Run the and apply the deployment.
```
kubectl apply -f deployment.yaml
kubectl get pods
curl localhost:8000   # To check whether nginx is deployed and working fine.
```

Now copy the public IPs of two running EC2 instances and paste into the browser and at the end of IP pass port number <:8000>.
You must see NGINX deployed and working.
After adding our target groups and listener to ALB, copy DNS name url in ALB aws console and paste the url to the browser and pass the port at the end url:8000. Now you can see NGINX deployed and ALB loadbalancing the traffic to both clusters.
If you want to change the cluster port, then just go to the <root/main.tf> "loadbalancing" module and changeonly "listener_port = 8000", don't change "tg_port = 8000" as it is mapped in for ALB.

====================================================================================
