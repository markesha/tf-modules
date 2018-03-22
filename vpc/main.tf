data "aws_availability_zones" "available" {}

resource "aws_vpc" "vpc" {
  cidr_block = "${var.cidr_block}"

  tags {
    Name = "tf-${var.env}-vpc"
  }
}

resource "aws_subnet" "subnet" {

  cidr_block = "10.0.1.0/24"
  vpc_id = "${aws_vpc.vpc.id}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  tags {
    Name = "tf-${var.env}-subnet-public"
  }
}

resource "aws_subnet" "subnet1" {

  cidr_block = "10.0.2.0/24"
  vpc_id = "${aws_vpc.vpc.id}"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  tags {
    Name = "tf-${var.env}-subnet-private"
  }
}

resource "aws_subnet" "subnet2" {

  cidr_block = "10.0.3.0/24"
  vpc_id = "${aws_vpc.vpc.id}"
  availability_zone = "${data.aws_availability_zones.available.names[2]}"
  tags {
    Name = "tf-${var.env}-subnet-private"
  }
}

resource "aws_route_table" "route_table_private" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags {
    Name = "tf-${var.env}-RT-private"
  }
}

resource "aws_main_route_table_association" "main_rt_association" {
  route_table_id = "${aws_route_table.route_table_private.id}"
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_route_table_association" "route_table_association_1" {
  route_table_id = "${aws_route_table.route_table_private.id}"
  subnet_id = "${aws_subnet.subnet1.id}"
}

resource "aws_route_table_association" "route_table_association_2" {
  route_table_id = "${aws_route_table.route_table_private.id}"
  subnet_id = "${aws_subnet.subnet2.id}"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "tf-${var.env}-igw"
  }
}

resource "aws_eip" "elp_nat" {
  vpc = true
  depends_on = ["aws_internet_gateway.igw"]

  tags {
    Name = "tf-${var.env}-eip"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = "${aws_eip.elp_nat.id}"
  subnet_id = "${aws_subnet.subnet.id}"
}

resource "aws_security_group" "allow_http" {
  name = "allow_http"
  description = "A rule for ELB"

  ingress {
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name = "tf-${var.env}-sg"
  }

}