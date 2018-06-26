# Specify the provider and access details
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "public-private-vpc" {
  cidr_block = "${var.vpc_ip_cidr}"
  tags {
    Name = "public-private-vpc"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "public-private-igw" {
  vpc_id = "${aws_vpc.public-private-vpc.id}"
  tags {
    Name = "public-private-igw"
  }
}

resource "aws_default_route_table" "r" {
  default_route_table_id = "${aws_vpc.public-private-vpc.default_route_table_id}"

  tags {
    Name = "public_routes"
  }
}

# Grant the VPC internet access on its main route table
resource "aws_route" "public_route" {
  route_table_id         = "${aws_vpc.public-private-vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.public-private-igw.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "public_sn_ap_south_1a" {
  vpc_id                  = "${aws_vpc.public-private-vpc.id}"
  cidr_block              = "${var.public_sn_cidr}"
  map_public_ip_on_launch = true
  availability_zone       = "${var.public_az}"
  tags {
    Name = "public_sn_ap_south_1a"
  }
}

resource "aws_subnet" "private_sn_ap_south_1b" {
  vpc_id                  = "${aws_vpc.public-private-vpc.id}"
  cidr_block              = "${var.private_sn_cidr}"
  availability_zone       = "${var.private_az}"
  tags {
    Name = "private_sn_ap_south_1b"
  }
}

resource "aws_subnet" "private_sn_ap_south_1a" {
  vpc_id                  = "${aws_vpc.public-private-vpc.id}"
  cidr_block              = "${var.private_sn_cidr2}"
  availability_zone       = "${var.private_az2}"
  tags {
    Name = "private_sn_ap_south_1a"
  }
}

resource "aws_eip" "private_eip" {
  vpc      = true
  depends_on = ["aws_internet_gateway.public-private-igw"]
  tags {
    Name = "private_eip"
  }
}

resource "aws_nat_gateway" "ngw" {
   allocation_id = "${aws_eip.private_eip.id}"
   subnet_id = "${aws_subnet.public_sn_ap_south_1a.id}"
   depends_on = ["aws_internet_gateway.public-private-igw"]
   tags {
    Name = "ngw"
  }
}

resource "aws_route_table" "private_routes" {
    vpc_id = "${aws_vpc.public-private-vpc.id}"

    tags {
        Name = "Private route table"
    }
}

resource "aws_route" "private_route" {
   route_table_id  = "${aws_route_table.private_routes.id}"
   destination_cidr_block = "0.0.0.0/0"
   nat_gateway_id = "${aws_nat_gateway.ngw.id}"
}

# Associate subnet public_subnet_eu_west_1a to public route table
resource "aws_route_table_association" "public_subnet_association" {
    subnet_id = "${aws_subnet.public_sn_ap_south_1a.id}"
    route_table_id = "${aws_vpc.public-private-vpc.main_route_table_id}"
}

# Associate subnet private_1_subnet_eu_west_1a to private route table
resource "aws_route_table_association" "pr_1_subnet_association" {
    subnet_id = "${aws_subnet.private_sn_ap_south_1b.id}"
    route_table_id = "${aws_route_table.private_routes.id}"
}
resource "aws_route_table_association" "pr_2_subnet_association" {
    subnet_id = "${aws_subnet.private_sn_ap_south_1a.id}"
    route_table_id = "${aws_route_table.private_routes.id}"
}
# A security group for the public so it is accessible via the web
resource "aws_security_group" "jump_server" {
  name        = "jump_server"
  description = "Used to login private instances"
  vpc_id      = "${aws_vpc.public-private-vpc.id}"

  # HTTP access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.mylocalip}/32"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "bastion_client" {
  name        = "bastion_client"
  description = "Used in private SNs"
  vpc_id      = "${aws_vpc.public-private-vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 1024
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = ["${aws_security_group.jump_server.id}"]
  }
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_ip_cidr}"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_ip_cidr}"]
  }
  
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.vpc_ip_cidr}"]
  }
}
resource "aws_security_group" "db_security_group" {
  name        = "db_security_group"
  description = "Used in private SNs"
  vpc_id      = "${aws_vpc.public-private-vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = ["${aws_security_group.bastion_client.id}"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.vpc_ip_cidr}"]
  }
}

resource "aws_default_network_acl" "default" {
  default_network_acl_id = "${aws_vpc.public-private-vpc.default_network_acl_id}"

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  subnet_ids = ["${aws_subnet.public_sn_ap_south_1a.id}"]
  tags {
    Name="public-nacl"
  }
}
resource "aws_network_acl" "private_nacl" {
  vpc_id = "${aws_vpc.public-private-vpc.id}"

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "${var.vpc_ip_cidr}"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "${var.vpc_ip_cidr}"
    from_port  = 0
    to_port    = 0
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  subnet_ids = ["${aws_subnet.private_sn_ap_south_1b.id}","${aws_subnet.private_sn_ap_south_1a.id}"]
  tags {
    Name = "private-nacl"
  }
}

resource "aws_instance" "jump_server" {

  instance_type = "t2.micro"

  # Lookup the correct AMI based on the region
  # we specified
  ami = "${lookup(var.aws_amis, var.region)}"

  # The name of our SSH keypair we created above.
  key_name = "testec2"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.jump_server.id}"]

  subnet_id = "${aws_subnet.public_sn_ap_south_1a.id}"
  tags {
    Name="jump server"
  }
}
resource "aws_instance" "private_server" {

  instance_type = "t2.micro"

  # Lookup the correct AMI based on the region
  # we specified
  ami = "${lookup(var.aws_amis, var.region)}"

  # The name of our SSH keypair we created above.
  key_name = "testec2"
  iam_instance_profile = "private-db-master"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.bastion_client.id}"]

  subnet_id = "${aws_subnet.private_sn_ap_south_1b.id}"
  user_data="${var.userdata}"
  tags {
    Name="private instance"
  }

}
resource "aws_db_subnet_group" "default" {
  name       = "private group"
  subnet_ids = ["${aws_subnet.private_sn_ap_south_1b.id}","${aws_subnet.private_sn_ap_south_1a.id}"]

  tags {
    Name = "private DB subnet group"
  }
}
resource "aws_db_instance" "default" {
  identifier           = "privatedb"
  allocated_storage    = 10
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.6"
  instance_class       = "db.t2.micro"
  db_subnet_group_name = "${aws_db_subnet_group.default.id}"
  name                 = "mydb"
  username             = "foo"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql5.6"
  vpc_security_group_ids = ["${aws_security_group.db_security_group.id}"]
  skip_final_snapshot  = true
}
resource "aws_lb_target_group" "privatetargets" {
  name     = "privatetargets"
  port     = 80
  protocol = "TCP"
  vpc_id   = "${aws_vpc.public-private-vpc.id}"
}
resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = "${aws_lb_target_group.privatetargets.arn}"
  target_id        = "${aws_instance.private_server.id}"
  port             = 80
}
resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = true
  load_balancer_type = "network"
  subnets            = ["${aws_subnet.private_sn_ap_south_1b.id}","${aws_subnet.private_sn_ap_south_1a.id}"]

  enable_deletion_protection = false

  tags {
    Environment = "dev"
  }
}
resource "aws_lb_listener" "testlistener1" {
  load_balancer_arn = "${aws_lb.test.arn}"
  port              = "80"
  protocol          = "TCP"

  default_action {
    target_group_arn = "${aws_lb_target_group.privatetargets.arn}"
    type             = "forward"
  }
}
resource "aws_api_gateway_vpc_link" "example" {
  name = "example"
  description = "none"
  target_arns = ["${aws_lb.test.arn}"]
}
