variable "aws_region" {
  type        = string
  description = "AWS region for deployment"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "dev"
}

variable "project_name" {
  type        = string
  description = "Project name prefix"
  default     = "docbridge"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for dev VPC"
  default     = "10.0.0.0/16"
}

variable "db_engine_version" {
  type        = string
  description = "PostgreSQL engine version"
  default     = "17.9"
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Allocated storage in GB"
  default     = 20
}