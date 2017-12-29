resource "aws_launch_configuration" "example" {

  instance_type = "${var.instance_type}"
  user_data = "${element(concat(data.template_file.user_data.*.rendered, data.template_file.user_data_new.*.rendered),0)}"

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

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  name = "${var.cluster_name}-${aws_launch_configuration.example.name}"

  availability_zones = ["${data.aws_availability_zones.all.names}"]
  launch_configuration = "${aws_launch_configuration.example.id}"
  load_balancers = ["${aws_elb.example.name}"]
  health_check_type = "ELB"

  max_size = "${var.max_size}"
  min_size = "${var.min_size}"
  min_elb_capacity = "${var.min_size  }"
  desired_capacity = 2

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key = "Name"
    value = "${var.cluster_name}"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  count = "${var.enable_autoscaling}"

  scheduled_action_name = "scale-out-during-business-hounrs"
  min_size = 2
  max_size = 2
  desired_capacity = 2
  recurrence = "0 9 * * *"
  autoscaling_group_name = "${aws_autoscaling_group.example.name}"
}

resource "aws_autoscaling_schedule" "scale_in_at_night" {
  count = "${var.enable_autoscaling}"

  scheduled_action_name = "scale-in-at-night"
  min_size = 2
  max_size = 2
  desired_capacity = 2
  recurrence = "0 17 * * *"
  autoscaling_group_name = "${aws_autoscaling_group.example.name}"
}

resource "aws_cloudwatch_metric_alarm" "low_cpu_credit_balance" {
  count = "${format("%.1s", var.instance_type) == "t" ? 1 : 0}"
  
  alarm_name = "${var.cluster_name}-low-cpu-credit-balance"
  namespace = "AWS/EC2"
  metric_name = "CPUCreditBalance"
  
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.example.name}"
  }
  
  comparison_operator = "LessThanThreshold"
  evaluation_periods = 1
  period = 300
  statistic = "Minimum"
  threshold = 10
  unit = "Count"
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

  lifecycle {
    create_before_destroy = true
  }
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
  count = "${1 - var.enable_new_user_data}"

  vars {
    server_port = "${var.server_port}"
    db_address = "${data.terraform_remote_state.db.address}"
    db_port = "${data.terraform_remote_state.db.port}"
  }
}

data "template_file" "user_data_new" {

  count = "${var.enable_new_user_data}"
  template = "${file("${path.module}/user-data-new.sh")}"

  vars {
    server_port = "${var.server_port}"
    server_text = "${var.server_text}"
  }
}