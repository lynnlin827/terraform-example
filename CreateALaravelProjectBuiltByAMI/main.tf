provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "us-west-2"
}

# Network
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

resource "aws_subnet" "private_subnet_2a" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.0.5.0/24"
  availability_zone = "us-west-2a"
  tags {
    Name = "tf-private-subnet-2a"
  }
}

resource "aws_subnet" "private_subnet_2b" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.0.6.0/24"
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

resource "aws_route_table_association" "public_subnet_2a_routing" {
  subnet_id = "${aws_subnet.public_subnet_2a.id}"
  route_table_id = "${aws_route_table.public_route_table.id}"
}

resource "aws_route_table_association" "public_subnet_2b_routing" {
  subnet_id = "${aws_subnet.public_subnet_2b.id}"
  route_table_id = "${aws_route_table.public_route_table.id}"
}

resource "aws_security_group" "sg_webserver" {
  name = "tf-sg-webserver"
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
    Name = "tf-sg-webserver"
  }
}

# Database
resource "aws_security_group" "sg_mysql" {
  name = "tf-sg-mysql"
  vpc_id = "${aws_vpc.vpc.id}"
  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "TCP"
    security_groups = ["${aws_security_group.sg_webserver.id}"]
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
  name = "todo"
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

resource "aws_route53_zone" "private_hosted_zone" {
  name = "lynn.demo"
  vpc_id = "${aws_vpc.vpc.id}"
  tags {
    Name = "tf-private-hosted-zone"
  }
}

resource "aws_route53_record" "domain_record_db" {
  name = "db.lynn.demo"
  type = "CNAME"
  zone_id = "${aws_route53_zone.private_hosted_zone.zone_id}"
  ttl = 300
  records = ["${aws_db_instance.mysql.address}"]
}

# Storage
resource "aws_s3_bucket" "s3" {
  bucket = "tf-s3-laravel-demo-project"
  acl = "private"
}

resource "aws_cloudfront_distribution" "s3_cdn" {
  origin {
    domain_name = "${aws_s3_bucket.s3.bucket_domain_name}"
    origin_id = "tf-s3-laravel-demo-project"
  }
  enabled = true
  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]
    default_ttl = 60
    min_ttl = 0
    max_ttl = 300
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    target_origin_id = "tf-s3-laravel-demo-project"
    viewer_protocol_policy = "redirect-to-https"
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  price_class = "PriceClass_100"
}

# Instance Authorization
data "aws_iam_policy_document" "iam_policy_ec2_default" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "iam_role_ec2" {
  name_prefix = "tf-role-ec2-"
  assume_role_policy = "${data.aws_iam_policy_document.iam_policy_ec2_default.json}"
}

data "aws_iam_policy_document" "iam_policy_ec2_access_s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:*",
    ]
    resources = [
      "${aws_s3_bucket.s3.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "iam_policy_ec2_access_s3" {
  name = "tf-policy-ec2-access-s3"
  policy = "${data.aws_iam_policy_document.iam_policy_ec2_access_s3.json}"
}

resource "aws_iam_policy_attachment" "iam_policy_attach_ec2" {
  name = "tf-attach-policy-ec2-access-s3"
  roles = ["${aws_iam_role.iam_role_ec2.name}"]
  policy_arn = "${aws_iam_policy.iam_policy_ec2_access_s3.arn}"
}

resource "aws_iam_instance_profile" "iam_role_ec2_pofile" {
  name_prefix = "tf-instance-profile-"
  role = "${aws_iam_role.iam_role_ec2.name}"
}

# Load Balance
resource "aws_lb_target_group" "alb_webserver_tg" {
  name = "tf-alb-tg-webserver-page"
  port = 80
  protocol = "HTTP"
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_lb" "alb_webserver" {
  name = "tf-alb-webserver"
  internal = false
  security_groups = ["${aws_security_group.sg_webserver.id}"]
  subnets = ["${aws_subnet.public_subnet_2a.id}", "${aws_subnet.public_subnet_2b.id}"]
}

resource "aws_lb_listener" "alb_webserver_listen" {
  load_balancer_arn = "${aws_lb.alb_webserver.arn}"
  port = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = "${aws_lb_target_group.alb_webserver_tg.arn}"
    type = "forward"
  }
}

data "template_file" "user_data" {
  template = "${file("CreateALaravelProjectBuiltByAMI/user_data.tpl")}"
  vars {
    image_domain = "${aws_cloudfront_distribution.s3_cdn.domain_name}"
  }
}

resource "aws_launch_configuration" "as_launch_config" {
  name_prefix = "tf-as-launch-config-"
  image_id = "ami-83ca70fb"
  instance_type = "t2.micro"
  key_name = "terraform"
  security_groups = ["${aws_security_group.sg_webserver.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.iam_role_ec2_pofile.name}"
  user_data = "${data.template_file.user_data.rendered}"
  associate_public_ip_address = true
}

resource "aws_autoscaling_group" "as_group" {
  name_prefix = "tf-as-group-"
  launch_configuration = "${aws_launch_configuration.as_launch_config.name}"
  min_size = 2
  max_size = 4
  desired_capacity = 3
  vpc_zone_identifier = ["${aws_subnet.public_subnet_2a.id}", "${aws_subnet.public_subnet_2b.id}"]
  target_group_arns = ["${aws_lb_target_group.alb_webserver_tg.arn}"]
  depends_on = [
    "aws_db_instance.mysql",
    "aws_cloudfront_distribution.s3_cdn"
  ]
}

# CDN
resource "aws_cloudfront_distribution" "webserver_cdn" {
  origin {
    domain_name = "${aws_lb.alb_webserver.dns_name}"
    origin_id = "tf-alb-webserver"

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2", "SSLv3"]
    }
  }
  enabled = true
  default_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods = ["GET", "HEAD"]
    default_ttl = 0
    min_ttl = 0
    max_ttl = 0
    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }
    target_origin_id = "tf-alb-webserver"
    viewer_protocol_policy = "redirect-to-https"
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  price_class = "PriceClass_100"
}

output "alb_dns" {
  value = "${aws_lb.alb_webserver.dns_name}"
}

output "cdn_dns" {
  value = "${aws_cloudfront_distribution.webserver_cdn.domain_name}"
}
