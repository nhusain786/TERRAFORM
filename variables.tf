variable "project_name" {
  description = "Application project name used for naming resources"
  type        = string
  default     = "three-tier-app"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "backend_region" {
  description = "AWS region for Terraform backend state bucket"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDRs are required."
  }
}

variable "app_subnet_cidrs" {
  description = "CIDR blocks for the application private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]

  validation {
    condition     = length(var.app_subnet_cidrs) == 2
    error_message = "Exactly two app subnet CIDRs are required."
  }
}

variable "db_subnet_cidrs" {
  description = "CIDR blocks for the database private subnets"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]

  validation {
    condition     = length(var.db_subnet_cidrs) == 2
    error_message = "Exactly two DB subnet CIDRs are required."
  }
}

variable "web_instance_type" {
  description = "EC2 instance type for the web tier"
  type        = string
  default     = "t3.micro"
}

variable "app_instance_type" {
  description = "EC2 instance type for the app tier"
  type        = string
  default     = "t3.micro"
}

variable "web_desired_capacity" {
  description = "Desired number of web tier instances"
  type        = number
  default     = 2
}

variable "web_min_size" {
  description = "Minimum number of web tier instances"
  type        = number
  default     = 2
}

variable "web_max_size" {
  description = "Maximum number of web tier instances"
  type        = number
  default     = 4
}

variable "aws_access_key" {
  description = "AWS access key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret access key"
  type        = string
  sensitive   = true
}

variable "app_desired_capacity" {
  description = "Desired number of app tier instances"
  type        = number
  default     = 2
}

variable "app_min_size" {
  description = "Minimum number of app tier instances"
  type        = number
  default     = 2
}

variable "app_max_size" {
  description = "Maximum number of app tier instances"
  type        = number
  default     = 4
}

variable "app_port" {
  description = "Port used by app tier instances"
  type        = number
  default     = 8080
}

variable "http_port" {
  description = "Port for HTTP traffic on the ALB"
  type        = number
  default     = 80
}

variable "https_port" {
  description = "Port for HTTPS traffic on the ALB"
  type        = number
  default     = 443
}

variable "enable_https" {
  description = "Enable HTTPS listener on the ALB"
  type        = bool
  default     = false
}

variable "alb_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS listener"
  type        = string
  default     = ""
}

variable "db_engine" {
  description = "Aurora engine to use"
  type        = string
  default     = "aurora-mysql"
}

variable "db_engine_version" {
  description = "Aurora engine version"
  type        = string
  default     = "3.03.0"
}

variable "db_instance_class" {
  description = "Instance class for Aurora cluster instances"
  type        = string
  default     = "db.t4g.small"
}

variable "db_name" {
  description = "Database name for the Aurora cluster"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the Aurora cluster"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password for the Aurora cluster"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "db_backup_retention_period" {
  description = "Aurora backup retention period in days"
  type        = number
  default     = 7
}

variable "db_backup_window" {
  description = "Preferred backup window for Aurora cluster"
  type        = string
  default     = "07:00-09:00"
}

variable "tags" {
  description = "Tags applied to all AWS resources"
  type        = map(string)
  default = {
    Environment = "production"
    Project     = "three-tier"
    ManagedBy   = "Terraform"
  }
}
