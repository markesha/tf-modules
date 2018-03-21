variable "env" {
  description = "The env type (prod/stage/etc)"
  default = "dev"
}

variable "region" {
  description = "The aws region (eu-central-1)"
  default = "eu-central-1"
}

variable "range" {
  description = "CIDR range for vpc"
  default = "10.0.0.0/16"
}