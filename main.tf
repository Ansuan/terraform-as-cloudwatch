terraform {
  required_version = ">=0.11.13"
}

provider "aws" {
  region  = "${var.region}"
  profile = "default"
}

resource "aws_key_pair" "ssh_key" {
  public_key = "${file("${var.ssh}")}"
  key_name   = "ssh_emergya"
}

//resource "aws_instance" "web" {
//  ami               = "${var.ami}"
//  count             = "${var.count}"
//  key_name               = "${aws_key_pair.ssh_key.key_name}"
//  vpc_security_group_ids = ["${aws_security_group.emergya-sg.id}"]
//  source_dest_check = false
//  instance_type = "t2.micro"
//  user_data="${data.template_file.web.rendered}"
//  tags {
//    Name = "emergya-instance-as"
//  }
//}
### Creating Security Group for EC2
resource "aws_security_group" "emergya-sg" {
  name = "emergya-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## Creating Launch Configuration
resource "aws_launch_configuration" "emergya-as-config" {
  image_id        = "${var.ami}"
  instance_type   = "t2.micro"
  security_groups = ["${aws_security_group.emergya-sg.id}"]
  key_name        = "${aws_key_pair.ssh_key.key_name}"
  user_data       = "${data.template_file.web.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

## Creating AutoScaling Group
resource "aws_autoscaling_group" "emergya-as-group" {
  launch_configuration = "${aws_launch_configuration.emergya-as-config.id}"
  availability_zones   = ["${data.aws_availability_zones.all.names}"]
  min_size             = 2
  max_size             = 3
  load_balancers       = ["${aws_elb.emergya-elb.name}"]
  health_check_type    = "ELB"

  tag {
    key                 = "Name"
    value               = "emergya-instance-as"
    propagate_at_launch = true
  }
}

## Security Group for ELB
resource "aws_security_group" "emergya-sg-elb" {
  name = "emergya-elb"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### Creating ELB
resource "aws_elb" "emergya-elb" {
  name               = "emergya-elb"
  security_groups    = ["${aws_security_group.emergya-sg-elb.id}"]
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 3
    interval            = 30
    target              = "HTTP:80/"
  }

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "80"
    instance_protocol = "http"
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_high" {
  alarm_name          = "CPU-Utilization-High-Instances"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "${var.instance_as_cpu_high_threshold_per}"
  alarm_actions       = ["${aws_autoscaling_policy.instance_up.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_low" {
  alarm_name          = "CPU-Utilization-Low-Instances"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "${var.instance_as_cpu_low_threshold_per}"
  alarm_actions       = ["${aws_autoscaling_policy.instance_down.arn}"]
}

resource "aws_autoscaling_policy" "instance_up" {
  name                   = "instance-up"
  autoscaling_group_name = "${aws_autoscaling_group.emergya-as-group.name}"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
}

resource "aws_autoscaling_policy" "instance_down" {
  name                   = "instance-down"
  autoscaling_group_name = "${aws_autoscaling_group.emergya-as-group.name}"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
}
