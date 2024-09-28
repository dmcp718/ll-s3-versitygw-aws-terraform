variable "instance_name" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "ll-s3-gw"
}

variable "instance_type" {
  description = "Value of the EC2 instance type"
  type        = string
  default     = "c5.2xlarge"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.10.0/24"
}

variable "domain_name" {
  type    = string
  default = "example.net"
}

variable "subdomain_name" {
  type    = string
  default = "s3.example.net"
}

variable "ami_id" {
  type    = string
  default = "null"
}

variable "region" {
  type    = string
  default = "us-east-2"
}