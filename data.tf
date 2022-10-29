data "aws_region" "current" {}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "tag:Name"
    values = ["*public*"]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "template_file" "env_vars" {
  template = file("env_vars.json")
}