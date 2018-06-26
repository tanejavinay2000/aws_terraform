variable "access_key" {
type="string"
default="<<your access key here>>"
}
variable "secret_key" {
type="string"
default="<<your secret_key here>>"
}
variable "region" {
  default = "<<region of your choice>>"
}
variable "mylocalip"{
type="string"
default="<<your public ip to secure your instances>>"
}
variable "vpc_ip_cidr" {
type="string"
default="10.0.0.0/25"
}
variable "private_sn_cidr" {
type="string"
default="10.0.0.0/27"
}
variable "public_sn_cidr" {
type="string"
default="10.0.0.32/27"
}
variable "private_sn_cidr2" {
type="string"
default="10.0.0.64/27"
}
variable "public_az" {
type="string"
default="<<public subnet availability zone>>"
}
variable "private_az" {
type="string"
default="<<private subnet availability zone 1>>"
}
variable "private_az2" {
type="string"
default="<<private subnet availability zone 2>>"
}
variable "aws_amis" {
  default = {
    ap-south-1 = "ami-b46f48db"
    us-east-1 = "ami-1d4e7a66"
    us-west-1 = "ami-969ab1f6"
    us-west-2 = "ami-8803e0f0"
  }
}

variable userdata {
	default=<<EOF
#!/bin/bash
sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo chkconfig docker on
	EOF
}
