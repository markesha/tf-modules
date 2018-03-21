resource "aws_vpc" "vpc" {
  cidr_block = "${var.range}"

  tags {
    Name = "${var.env}-vpc"
  }
}