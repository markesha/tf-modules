resource "aws_launch_configuration" "example" {

  instance_type = "${var.instance_type}"
  user_data = "${data.template_file.user_data.rendered}"

  security_groups = ["${aws_security_group.instance.id}"]
  image_id = "ami-40d28157"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "example" {
  name = "${var.cluster_name}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  security_groups = ["${aws_security_group.elb.id}"]

  "listener" {
    instance_port = "${var.server_port}"
    instance_protocol = "http"
    lb_port = "${var.elb_port}"
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    interval = 30
    target = "HTTP:${var.server_port}/"
    timeout = 3
    unhealthy_threshold = 2
  }
}
resource "aws_autoscaling_group" "example" {
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  launch_configuration = "${aws_launch_configuration.example.id}"

  load_balancers = ["${aws_elb.example.name}"]
  health_check_type = "ELB"

  max_size = "${var.max_size}"
  min_size = "${var.min_size}"
  desired_capacity = 2
  
  tag {
    key = "Name"
    value = "${var.cluster_name}"
    propagate_at_launch = true
  }
}
resource "aws_security_group" "instance" {
  name = "${var.cluster_name}-instance"

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_security_group_rule" "allow_custom" {
  from_port = "${var.server_port}"
  protocol = "tcp"
  security_group_id = "${aws_security_group.instance.id}"
  to_port = "${var.server_port}"
  type = "ingress"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group" "elb" {
  name = "${var.cluster_name}-elb"
}

resource "aws_security_group_rule" "allow_http_inbound" {
  from_port = 80
  protocol = "tcp"
  security_group_id = "${aws_security_group.elb.id}"
  to_port = 80
  type = "ingress"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_all_outbound" {
  from_port = 0
  protocol = "-1"
  security_group_id = "${aws_security_group.elb.id}"
  to_port = 0
  type = "egress"
  cidr_blocks = ["0.0.0.0/0"]
}

data "aws_availability_zones" "all" {}

data "terraform_remote_state" "db" {
  backend = "s3"

  config {
    bucket = "${var.db_remote_state_bucket}"
    key = "${var.db_remote_state_key}"
    region = "us-east-1"
  }
}


data "template_file" "user_data" {
  template = "${file("${path.module}/user-data.sh")}"

  vars {
    server_port = "${var.server_port}"
    db_address = "${data.terraform_remote_state.db.address}"
    db_port = "${data.terraform_remote_state.db.port}"
  }
}