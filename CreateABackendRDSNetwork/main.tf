provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "us-west-2"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags {
    Name = "tf-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.0.1.0/24"
  tags {
    Name = "tf-public-subnet"
  }
}

resource "aws_subnet" "private_subnet_2a" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-2a"
  tags {
    Name = "tf-private-subnet-2a"
  }
}

resource "aws_subnet" "private_subnet_2b" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-west-2b"
  tags {
    Name = "tf-private-subnet-2b"
  }
}

resource "aws_internet_gateway" "public_facing" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags {
    Name = "tf-internet-gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.public_facing.id}"
  }
}

resource "aws_route_table_association" "public_subnet_routing" {
  subnet_id = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_route_table.public_route_table.id}"
}

resource "aws_security_group" "sg_api_server" {
  name = "tf-sg-api-server"
  vpc_id = "${aws_vpc.vpc.id}"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "TCP"
    cidr_blocks = ["${var.my_ip}"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name = "tf-sg-api-server"
  }
}

resource "aws_security_group" "sg_mysql" {
  name = "tf-sg-mysql"
  vpc_id = "${aws_vpc.vpc.id}"
  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "TCP"
    security_groups = ["${aws_security_group.sg_api_server.id}"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name = "tf-sg-mysql"
  }
}

resource "aws_db_subnet_group" "mysql_subnet_group" {
  name = "tf-mysql-subnet-group"
  subnet_ids = ["${aws_subnet.private_subnet_2a.id}", "${aws_subnet.private_subnet_2b.id}"]
  tags {
    Name = "tf-mysql-subnet-group"
  }
}

resource "aws_db_parameter_group" "mysql_parameters" {
  name = "tf-mysql-paramters"
  family = "mysql5.6"
  parameter {
    name  = "character_set_server"
    value = "utf8"
  }
}

resource "aws_db_option_group" "mysql_options" {
  name = "tf-mysql-options"
  engine_name = "mysql"
  major_engine_version = "5.6"
}

resource "aws_db_instance" "mysql" {
  identifier = "tf-mysql"
  allocated_storage = 20
  storage_type = "gp2"
  engine = "mysql"
  instance_class = "db.t2.micro"
  name = "terraform"
  username = "root"
  password = "password"
  db_subnet_group_name = "tf-mysql-subnet-group"
  vpc_security_group_ids = ["${aws_security_group.sg_mysql.id}"]
  auto_minor_version_upgrade = false
  skip_final_snapshot = true
  parameter_group_name = "tf-mysql-paramters"
  option_group_name = "tf-mysql-options"
  depends_on = [
    "aws_db_subnet_group.mysql_subnet_group",
    "aws_db_parameter_group.mysql_parameters",
    "aws_db_option_group.mysql_options"
  ]
}

resource "aws_instance" "ec2" {
  ami = "ami-f2d3638a"
  instance_type = "t2.micro"
  key_name = "terraform"
  subnet_id = "${aws_subnet.public_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_api_server.id}"]
  associate_public_ip_address = true
  user_data = "${file("CreateABackendRDSNetwork/user_data.sh")}"
  tags {
    Name = "tf_ec2"
  }
}

output "ec2_dns" {
  value = "${aws_instance.ec2.public_dns}"
}

output "mysql_dns" {
  value = "${aws_db_instance.mysql.address}"
}
