data "aws_vpc" "vpc" {
  id = "${var.vpc_id}"
}
# ${data.aws_vpc.vpc.tags["Name"]}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier_prefix       = "tf-${var.name}-${data.aws_vpc.vpc.tags["Name"]}"
  availability_zones              = "${var.azs}"
  database_name                   = "${var.database_name}"
  master_username                 = "${var.master_username}"
  master_password                 = "${var.master_password}"
  backup_retention_period         = "${var.backup_retention_period}"
  preferred_backup_window         = "${var.preferred_backup_window}"
  vpc_security_group_ids          = ["${aws_security_group.aurora_security_group.id}"]
  storage_encrypted               = "${var.storage_encrypted}"
  kms_key_id                      = "${aws_kms_key.aurora.arn}"
  apply_immediately               = "${var.apply_immediately}"
  db_subnet_group_name            = "${aws_db_subnet_group.aurora_subnet_group.id}"
  db_cluster_parameter_group_name = "${aws_rds_cluster_parameter_group.aurora_cluster_parameter_group.id}"

  lifecycle {
    prevent_destroy               = "true" # https://www.terraform.io/docs/configuration/resources.html#prevent_destroy
  }
}

resource "aws_rds_cluster_instance" "aurora_instance" {
  count                   = "${var.cluster_size}"
  identifier_prefix       = "tf-rds-aurora-${var.name}-${data.aws_vpc.vpc.tags["Name"]}-${count.index}"
  cluster_identifier      = "${aws_rds_cluster.aurora.id}"
  instance_class          = "${var.instance_class}"
  publicly_accessible     = "false"
  db_subnet_group_name    = "${aws_db_subnet_group.aurora_subnet_group.id}"
  db_parameter_group_name = "${aws_db_parameter_group.aurora_parameter_group.id}"
  apply_immediately       = "${var.apply_immediately}"
  monitoring_role_arn     = "${aws_iam_role.aurora_instance_role.arn}"
  monitoring_interval     = "5"

  tags {
    Name = "tf-rds-aurora-${var.name}-${data.aws_vpc.vpc.tags["Name"]}-${count.index}"
  }
}

resource "aws_db_subnet_group" "aurora_subnet_group" {
  name       = "tf-rds-${var.name}-${data.aws_vpc.vpc.tags["Name"]}"
  subnet_ids = ["${var.subnets}"]

  tags {
    Name = "tf-rds-${var.name}-${data.aws_vpc.vpc.tags["Name"]}"
  }
}

resource "aws_db_parameter_group" "aurora_parameter_group" {
  name        = "tf-rds-${var.name}-${data.aws_vpc.vpc.tags["Name"]}"
  family      = "aurora5.6"
  description = "Terraform-managed parameter group for ${var.name}-${data.aws_vpc.vpc.tags["Name"]}"

  tags {
    Name = "tf-rds-${var.name}-${data.aws_vpc.vpc.tags["Name"]}"
  }
}

resource "aws_rds_cluster_parameter_group" "aurora_cluster_parameter_group" {
  name        = "tf-rds-${var.name}-${data.aws_vpc.vpc.tags["Name"]}"
  family      = "aurora5.6" # does this need a var?
  description = "Terraform-managed cluster parameter group for ${var.name}-${data.aws_vpc.vpc.tags["Name"]}"

  tags {
    Name = "tf-rds-${var.name}-${data.aws_vpc.vpc.tags["Name"]}"
  }
}

resource "aws_db_option_group" "aurora_option_group" {
  name                     = "tf-rds-${var.name}-${data.aws_vpc.vpc.tags["Name"]}"
  option_group_description = "Terraform-managed option group for ${var.name}-${data.aws_vpc.vpc.tags["Name"]}"
  engine_name              = "aurora"
  major_engine_version     = "5.6"
}

resource "aws_iam_role" "aurora_instance_role" {
  name               = "tf-role-rds-${var.name}-${data.aws_vpc.vpc.tags["Name"]}"
  assume_role_policy = "${file("${path.module}/files/iam/assume_role_rds_monitoring.json")}"
  path               = "/tf/${var.env}/${var.name}-${data.aws_vpc.vpc.tags["Name"]}/" # edits?
}

resource "aws_iam_role_policy_attachment" "aurora_policy_rds_monitoring" {
  role       = "${aws_iam_role.aurora_instance_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
