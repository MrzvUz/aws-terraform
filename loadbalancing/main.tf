# --- loadbalancing/main.tf ---

resource "aws_lb" "my_lb" {
  name            = "my-loadbalancer"
  subnets         = var.public_subnets
  security_groups = [var.public_sg]
  idle_timeout    = 400
}