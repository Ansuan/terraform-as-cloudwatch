variable "region" {
  type    = "string"
  default = "eu-west-1"
}

variable "ami" {
  type    = "string"
  default = "ami-0b2a4d260c54e8d3d"
}

variable "ssh" {
  type    = "string"
  default = "ssh.pub"
}

variable "count" {
  type    = "string"
  default = "1"
}

data "aws_availability_zones" "all" {}

data "template_file" "web" {
  template = "${file("templates/web.tpl")}"
}
variable "instance_as_cpu_low_threshold_per" {
  default = "20"
}

variable "instance_as_cpu_high_threshold_per" {
  default = "80"
}