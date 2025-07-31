variable "aws_region" {
  description = "Primary AWS region to deploy resources"
  default     = "eu-central-1"
}

variable "ami_id" {
  description = "Ubuntu AMI ID (Ubuntu 22.04 LTS)"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair to use for SSH"
  type        = string
}

variable "remote_ami_id" {
  description = "AMI for remote region (eu-west-1)"
  type        = string
}
variable "availability_zones" {
  description = "List of availability zones for multi-AZ deployment"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "db4_private_ip" {
  type        = string
  description = "Private IP for db4 replica in remote region"
}

variable "db4_az" {
  type        = string
  description = "Availability zone for db4 (eu-west-1a)"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}
