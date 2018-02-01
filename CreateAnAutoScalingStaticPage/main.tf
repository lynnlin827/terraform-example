provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "us-west-2"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags {
    Name = "tf-vpc"
  }
}

resource "aws_subnet" "public_subnet_2a" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  tags {
    Name = "tf-subnet-2a"
  }
}

resource "aws_subnet" "public_subnet_2b" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-2b"
  tags {
    Name = "tf-subnet-2b"
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

resource "aws_route_table_association" "public_subnet_2a_routing" {
  subnet_id = "${aws_subnet.public_subnet_2a.id}"
  route_table_id = "${aws_route_table.public_route_table.id}"
}

resource "aws_route_table_association" "public_subnet_2b_routing" {
  subnet_id = "${aws_subnet.public_subnet_2b.id}"
  route_table_id = "${aws_route_table.public_route_table.id}"
}

resource "aws_security_group" "allow_http_connection" {
  name = "tf-sg-allow-http-connection"
  vpc_id = "${aws_vpc.vpc.id}"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name = "tf-sg-allow-http-connection"
  }
}

resource "aws_lb_target_group" "alb_static_page_tg" {
  name = "tf-alb-tg-static-web-page"
  port = 80
  protocol = "HTTP"
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_lb" "alb_static_page" {
  name = "tf-alb-static-page"
  internal = false
  security_groups = ["${aws_security_group.allow_http_connection.id}"]
  subnets = ["${aws_subnet.public_subnet_2a.id}", "${aws_subnet.public_subnet_2b.id}"]
}

resource "aws_lb_listener" "alb_static_page_listen" {
  load_balancer_arn = "${aws_lb.alb_static_page.arn}"
  port = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = "${aws_lb_target_group.alb_static_page_tg.arn}"
    type = "forward"
  }
}

resource "aws_launch_configuration" "as_launch_config" {
  name = "tf-as-launch-config"
  image_id = "ami-f2d3638a"
  instance_type = "t2.micro"
  key_name = "terraform"
  user_data = "${file("CreateAnAutoScalingStaticPage/user_data.sh")}"
  security_groups = ["${aws_security_group.allow_http_connection.id}"]
  associate_public_ip_address = true
}

resource "aws_autoscaling_group" "as_group" {
  name = "tf-as-group"
  launch_configuration = "${aws_launch_configuration.as_launch_config.name}"
  min_size = 2
  max_size = 4
  desired_capacity = 3
  vpc_zone_identifier = ["${aws_subnet.public_subnet_2a.id}", "${aws_subnet.public_subnet_2b.id}"]
  target_group_arns = ["${aws_lb_target_group.alb_static_page_tg.arn}"]
}

output "alb_dns" {
  value = "${aws_lb.alb_static_page.dns_name}"
}
