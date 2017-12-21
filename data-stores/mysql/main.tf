resource "aws_db_instance" "example" {
  engine = "mysql"
  allocated_storage = 10
  instance_class = "${var.instance_class}"
  name = "${var.db_name}"
  username = "admin"
  password = "${var.db_password}"
}