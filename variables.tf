variable "app_name" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnets_cidr" {
  type = list(string)
}

variable "private_subnets_cidr" {
  type = list(string)
}

/* variable "vpc_id" {
  type = string
} */
