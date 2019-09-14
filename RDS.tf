#
# Terraform required version
#
terraform {
  required_version = ">= 0.8.0"
}

#
# IAM resources
#
data "aws_iam_policy_document" "enhanced_monitoring" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "enhanced_monitoring" {
  name               = "rds${var.environment}EnhancedMonitoringRole"
  assume_role_policy = "${data.aws_iam_policy_document.enhanced_monitoring.json}"
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  role       = "${aws_iam_role.enhanced_monitoring.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

#
# Security group resources
#
resource "aws_security_group" "postgresql" {
  # vpc_id = "${var.vpc_id}"
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name        = "sgDatabaseServer"
    Project     = "${var.project}"
    Environment = "${var.environment}"
  }
}

resource "aws_vpc" "main" {
  cidr_block       = "190.10.0.0/16"
  instance_tenancy = "default"
  #default = true

  tags = {
    Name = "db_vpc"
  }
}

# Create a subnet to launch our instances into
resource "aws_subnet" "frontend" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "190.10.1.0/24"
  map_public_ip_on_launch = true
}

# Create a subnet to launch our instances into
resource "aws_subnet" "backend" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "190.10.6.0/24"
  map_public_ip_on_launch = true
}

resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = ["${aws_subnet.frontend.id}", "${aws_subnet.backend.id}"]

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_db_parameter_group" "database" {
  name   = "database"
  family = "postgres9.5"

  parameter {
   name         = "rds.force_ssl"
   value        = "1"
   apply_method = "pending-reboot"
 }

}

#
# RDS resources
#
resource "aws_db_instance" "postgresql" {
  allocated_storage          = "${var.allocated_storage}"
  engine                     = "postgres"
  engine_version             = "${var.engine_version}"
  identifier                 = "${var.database_identifier}"
  snapshot_identifier        = "${var.snapshot_identifier}"
  instance_class             = "${var.instance_type}"
  storage_type               = "${var.storage_type}"
  iops                       = "${var.iops}"
  name                       = "${var.database_name}"
  password                   = "${var.database_password}"
  username                   = "${var.database_username}"
  backup_retention_period    = "${var.backup_retention_period}"
  backup_window              = "${var.backup_window}"
  maintenance_window         = "${var.maintenance_window}"
  auto_minor_version_upgrade = "${var.auto_minor_version_upgrade}"
  final_snapshot_identifier  = "${var.final_snapshot_identifier}"
  skip_final_snapshot        = "${var.skip_final_snapshot}"
  copy_tags_to_snapshot      = "${var.copy_tags_to_snapshot}"
  multi_az                   = "${var.multi_availability_zone}"
  port                       = "${var.database_port}"
  vpc_security_group_ids     = ["${aws_security_group.postgresql.id}"]
  db_subnet_group_name       = "${aws_db_subnet_group.default.id}"
  # db_subnet_group_name       = "${var.subnet_group}"
  # parameter_group_name       = "${var.parameter_group}"
  parameter_group_name       = "${aws_db_parameter_group.database.name}"
  storage_encrypted          = "${var.storage_encrypted}"
  monitoring_interval        = "${var.monitoring_interval}"
  monitoring_role_arn        = "${var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring.arn : ""}"
  deletion_protection        = "${var.deletion_protection}"

  tags = {
    Name        = "DatabaseServer"
    Project     = "${var.project}"
    Environment = "${var.environment}"
  }
}

#
# CloudWatch resources
#
