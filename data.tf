data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

data "aws_subnet" "selected" {
  for_each = toset(data.aws_subnets.all.ids)
  id       = each.value
}

# filter only public subnets
locals {
  public_subnet_ids = [
    for subnet_id, subnet in data.aws_subnet.selected : subnet_id
    if subnet.map_public_ip_on_launch == true
  ]
}