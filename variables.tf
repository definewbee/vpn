variable "region" {
  description = "The AWS region to create resources in"
  default     = "ap-southeast-1"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "The CIDR block for the public subnet"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "The CIDR block for the public subnet"
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}