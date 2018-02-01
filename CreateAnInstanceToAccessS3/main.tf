provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "us-west-2"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags {
    Name = "tf_vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "10.0.1.0/24"
  tags {
    Name = "tf_subnet"
  }
}

resource "aws_internet_gateway" "public_facing" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags {
    Name = "tf_internet_gateway"
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

resource "aws_security_group" "allow_ssh" {
  name = "allow_ssh"
  vpc_id = "${aws_vpc.vpc.id}"
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
    Name = "tf_sg"
  }
}

resource "aws_s3_bucket" "s3" {
  bucket_prefix = "tf-s3-"
  acl = "private"
}

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
      "${aws_s3_bucket.s3.arn}"
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
  # policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "iam_role_ec2_pofile" {
  name_prefix = "tf-instance-profile-"
  role = "${aws_iam_role.iam_role_ec2.name}"
}

resource "aws_instance" "ec2" {
  ami = "ami-f2d3638a"
  instance_type = "t2.micro"
  key_name = "terraform"
  subnet_id = "${aws_subnet.public_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.allow_ssh.id}"]
  associate_public_ip_address = true
  iam_instance_profile = "${aws_iam_instance_profile.iam_role_ec2_pofile.name}"
  tags {
    Name = "tf-ec2"
  }
}

output "instance_ip" {
  value = "${aws_instance.ec2.public_ip}"
}

output "instance_dns" {
  value = "${aws_instance.ec2.public_dns}"
}

output "s3_bukcet" {
  value = "${aws_s3_bucket.s3.id}"
}
