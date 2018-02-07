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
    Name = "tf-public-subnet-2a"
  }
}

resource "aws_subnet" "public_subnet_2b" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-2b"
  tags {
    Name = "tf-public-subnet-2b"
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

resource "aws_security_group" "sg_webserver_lb" {
  name_prefix = "tf-sg-webserver-lb-"
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

resource "aws_security_group" "sg_webserver_ecs_instance" {
  name_prefix = "tf-sg-webserver-ecs-instance-"
  vpc_id = "${aws_vpc.vpc.id}"
  ingress {
    from_port = 0
    to_port = 32777
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
  name_prefix = "tf-sg-mysql-"
  vpc_id = "${aws_vpc.vpc.id}"
  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "TCP"
    security_groups = ["${aws_security_group.sg_webserver_ecs_instance.id}"]
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
  name_prefix = "tf-mysql-subnet-group-"
  subnet_ids = ["${aws_subnet.private_subnet_2a.id}", "${aws_subnet.private_subnet_2b.id}"]
  tags {
    Name = "tf-mysql-subnet-group"
  }
}

resource "aws_db_parameter_group" "mysql_parameters" {
  name_prefix = "tf-mysql-paramters-"
  family = "mysql5.6"
  parameter {
    name  = "character_set_server"
    value = "utf8"
  }
}

resource "aws_db_option_group" "mysql_options" {
  name_prefix = "tf-mysql-options-"
  engine_name = "mysql"
  major_engine_version = "5.6"
}

resource "aws_db_instance" "mysql" {
  identifier_prefix = "tf-mysql-"
  allocated_storage = 20
  storage_type = "gp2"
  engine = "mysql"
  instance_class = "db.t2.micro"
  name = "todo"
  username = "root"
  password = "password"
  db_subnet_group_name = "${aws_db_subnet_group.mysql_subnet_group.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_mysql.id}"]
  auto_minor_version_upgrade = false
  skip_final_snapshot = true
  parameter_group_name = "${aws_db_parameter_group.mysql_parameters.id}"
  option_group_name = "${aws_db_option_group.mysql_options.id}"
  depends_on = [
    "aws_db_subnet_group.mysql_subnet_group",
    "aws_db_parameter_group.mysql_parameters",
    "aws_db_option_group.mysql_options"
  ]
}

resource "aws_route53_zone" "private_hosted_zone" {
  name = "${var.private_domain}"
  vpc_id = "${aws_vpc.vpc.id}"
  tags {
    Name = "tf-private-hosted-zone"
  }
}

resource "aws_route53_record" "domain_record_db" {
  name = "db.${var.private_domain}"
  type = "CNAME"
  zone_id = "${aws_route53_zone.private_hosted_zone.zone_id}"
  ttl = 300
  records = ["${aws_db_instance.mysql.address}"]
}

# Storage
resource "aws_s3_bucket" "s3" {
  bucket = "${var.s3_image_bucket}"
  acl = "private"
}

# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "tf-ecs-cluster-laravel-todo"
}

# Load Balance & Auto scaling
resource "aws_lb_target_group" "alb_webserver_tg" {
  name = "tf-alb-webserver-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_lb" "alb_webserver" {
  name = "tf-alb-webserver"
  internal = false
  security_groups = ["${aws_security_group.sg_webserver_lb.id}"]
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
  template = "${file("user_data.tpl")}"
  vars {
    ecs_cluster_name = "${aws_ecs_cluster.ecs_cluster.name}"
  }
}

resource "aws_launch_configuration" "as_launch_config" {
  name_prefix = "tf-as-launch-config-"
  image_id = "ami-decc7fa6"
  instance_type = "t2.micro"
  key_name = "terraform"
  iam_instance_profile = "ecsInstanceRole"
  user_data = "${data.template_file.user_data.rendered}"
  security_groups = ["${aws_security_group.sg_webserver_ecs_instance.id}"]
  associate_public_ip_address = true
}

resource "aws_autoscaling_group" "as_group" {
  name_prefix = "tf-as-group-"
  launch_configuration = "${aws_launch_configuration.as_launch_config.name}"
  min_size = 1
  max_size = 1
  desired_capacity = 1
  vpc_zone_identifier = ["${aws_subnet.public_subnet_2a.id}", "${aws_subnet.public_subnet_2b.id}"]
  target_group_arns = ["${aws_lb_target_group.alb_webserver_tg.arn}"]
}

# Instance Authorization
data "aws_iam_policy_document" "iam_policy_ecs_task_default" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "iam_role_ecs_task" {
  name_prefix = "tf-role-ecs-task-"
  assume_role_policy = "${data.aws_iam_policy_document.iam_policy_ecs_task_default.json}"
}

data "aws_iam_policy_document" "iam_policy_ecs_task_access_s3" {
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

resource "aws_iam_policy" "iam_policy_ecs_task_access_s3" {
  name_prefix = "tf-policy-ecs-access-s3-"
  policy = "${data.aws_iam_policy_document.iam_policy_ecs_task_access_s3.json}"
}

resource "aws_iam_policy_attachment" "iam_policy_attach_ecs" {
  name = "tf-attach-policy-ecs-access-s3"
  roles = ["${aws_iam_role.iam_role_ecs_task.name}"]
  policy_arn = "${aws_iam_policy.iam_policy_ecs_task_access_s3.arn}"
}

# ECS Task & Service
data "template_file" "task_def" {
  template = "${file("task_def.tpl")}"
  vars {
    private_domain = "${var.private_domain}"
    s3_image_bucket = "${var.s3_image_bucket}"
    docker_image = "${var.docker_image}"
  }
}

resource "aws_ecs_task_definition" "task_def" {
  family = "tf-ecs-task-def-laravel-todo"
  task_role_arn = "${aws_iam_role.iam_role_ecs_task.arn}"
  container_definitions = "${data.template_file.task_def.rendered}"
}

resource "aws_ecs_service" "ecs_service" {
  name = "tf-ecs-service-laravel-todo"
  cluster = "${aws_ecs_cluster.ecs_cluster.id}"
  task_definition = "${aws_ecs_task_definition.task_def.arn}"
  desired_count = 2
  load_balancer {
    target_group_arn = "${aws_lb_target_group.alb_webserver_tg.arn}"
    container_name = "demo-laravel-todo"
    container_port = 80
  }
  depends_on = [
    "aws_lb_listener.alb_webserver_listen",
    "aws_db_instance.mysql",
    "aws_route53_record.domain_record_db"
  ]
}

output "alb_dns" {
  value = "${aws_lb.alb_webserver.dns_name}"
}
