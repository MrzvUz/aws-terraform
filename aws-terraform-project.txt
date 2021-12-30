



* Creating Application Load Balancer:
* Create <loadbalancing> module.
* Create main.tf, variables.tf, outputs.tf files in load balancing module.
* Create ALB resource in loadbalancing/main.tf.

resource = "aws_lb" "my-lb" {
  name = "my-loadbalancer"
  subnets = var.public_subnets
  security_groups = [var.public_sg]
  idle_timeout = 400
}


* Create variables in loadbalancing/variables.tf file.

variable "public_sg" {}
variable "public_subnets" {}


* Create module block in root/main.tf file.

module "loadbalancing" {
  source = "./loadbalancing"
  public_sg = ""
  public_subnets = ""
}




