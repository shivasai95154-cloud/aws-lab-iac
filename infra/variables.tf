variable "region" {
  type    = string
  default = "ap-south-1"
}
variable "name" {
  type    = string
  default = "lab"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "enable_nat" {
  description = "Private servers need a NAT Gateway to install nginx (costs ~1 USD/day)"
  type        = bool
  default     = true
}
