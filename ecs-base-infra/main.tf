/*==================================================================================
              1. Create and configure a VPC to launch the resources in it
==================================================================================*/

resource "aws_vpc" "ecsinfra-vpc" {
  count      = var.dbmodule_active ? 0 : 1
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags       = var.tags
}

# Fetch AZs in the current region
data "aws_availability_zones" "available" {
}

# Create private subnets, each in a different AZ
resource "aws_subnet" "ecsinfra-private_subnet" {
  count             = var.dbmodule_active ? 0 : var.az_count
  cidr_block        = cidrsubnet(aws_vpc.ecsinfra-vpc[0].cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = var.dbmodule_active ? var.db_vpc_id : aws_vpc.ecsinfra-vpc[0].id
  tags              = var.tags
}

# Create public subnets, each in a different AZ
resource "aws_subnet" "ecsinfra-public_subnet" {
  count                   = var.dbmodule_active ? 0 : var.az_count
  cidr_block              = cidrsubnet(aws_vpc.ecsinfra-vpc[0].cidr_block, 8, var.az_count + count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = var.dbmodule_active ? var.db_vpc_id : aws_vpc.ecsinfra-vpc[0].id
  map_public_ip_on_launch = true
  tags                    = var.tags
}

# Internet Gateway for the public subnet
resource "aws_internet_gateway" "ecsinfra-igw" {
  count      = var.dbmodule_active ? 0 : 1
  vpc_id = var.dbmodule_active ? var.db_vpc_id : aws_vpc.ecsinfra-vpc[0].id
  tags   = var.tags
}

# Route the public subnet traffic through the IGW
resource "aws_route" "ecsinfra-internet_access" {
  count                  = var.dbmodule_active ? 0 : 1
  route_table_id         = aws_vpc.ecsinfra-vpc[0].main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ecsinfra-igw[0].id
}

# NAT gateway with an Elastic IP for each private subnet to get internet connectivity
resource "aws_eip" "ecsinfra-eip" {
  count      = var.dbmodule_active ? 0 : var.az_count
  vpc        = true
  depends_on = [aws_internet_gateway.ecsinfra-igw]
  tags       = var.tags
}

resource "aws_nat_gateway" "ecsinfra-natgw" {
  count         = var.dbmodule_active ? 0 : var.az_count
  subnet_id     = element(aws_subnet.ecsinfra-public_subnet.*.id, count.index)
  allocation_id = element(aws_eip.ecsinfra-eip.*.id, count.index)
  tags          = var.tags
}

# Create a new route table for the private subnets, make it route non-local traffic through the NAT gateway to the internet
resource "aws_route_table" "ecsinfra-private_rt" {
  count  = var.dbmodule_active ? 0 : var.az_count
  vpc_id = var.dbmodule_active ? var.db_vpc_id : aws_vpc.ecsinfra-vpc[0].id
  tags   = var.tags

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.ecsinfra-natgw.*.id, count.index)
  }
}

# Explicitly associate the newly created route tables to the private subnets (so they don't default to the main route table)
resource "aws_route_table_association" "ecsinfra-private_rt_assgn" {
  count          = var.dbmodule_active ? 0 : var.az_count
  subnet_id      = element(aws_subnet.ecsinfra-private_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.ecsinfra-private_rt.*.id, count.index)
}

/*==================================================================================
                       2. Security group for ALB and ECS
==================================================================================*/

# ALB Security Group: Edit to restrict access to the application
resource "aws_security_group" "ecsinfra-alb_sg" {
  name        = "${var.app_name}-load-balancer-security-group"
  description = "controls access to the ALB"
  vpc_id      = var.dbmodule_active ? var.db_vpc_id : aws_vpc.ecsinfra-vpc[0].id
  tags        = var.tags
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#ECS security group: Traffic to the ECS cluster should only come from the ALB
resource "aws_security_group" "ecsinfra-ecs_sg" {
  name        = "ecs-tasks-security-group"
  description = "allow inbound access from the ALB only"
  vpc_id      = var.dbmodule_active ? var.db_vpc_id : aws_vpc.ecsinfra-vpc[0].id
  tags        = var.tags
  ingress {
    protocol        = "-1"
    from_port       = 0
    to_port         = 0
    security_groups = [aws_security_group.ecsinfra-alb_sg.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#RDS security group rule: Traffic to the DB Instance should only come from the ECS
resource "aws_security_group_rule" "default-rule" {
  count                    = var.dbmodule_active ? 1 : 0
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = var.db-sg-id
  source_security_group_id = aws_security_group.ecsinfra-ecs_sg.id
}

/*==================================================================================
                 3. ECS cluster to launch the application in it
==================================================================================*/

resource "aws_ecs_cluster" "ecsinfra-cluster" {
  name = "${var.app_name}-cluster"
  tags = var.tags
}

/*==================================================================================
                     4. IAM role data for ECS task Execution
==================================================================================*/

data "aws_iam_policy_document" "assume_by_ecs" {
  statement {
    sid     = "AllowAssumeByEcsTasks"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "execution_role" {
  statement {
    sid    = "AllowECRLogging"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "task_role" {
  statement {
    sid    = "AllowDescribeCluster"
    effect = "Allow"

    actions = ["ecs:DescribeClusters"]

    resources = ["${aws_ecs_cluster.ecsinfra-cluster.arn}"]
  }
}

resource "aws_iam_role" "execution_role" {
  name               = "${var.app_name}_ecsTaskExecutionRole"
  assume_role_policy = "${data.aws_iam_policy_document.assume_by_ecs.json}"
  tags               = var.tags
}

resource "aws_iam_role_policy" "execution_role" {
  role   = "${aws_iam_role.execution_role.name}"
  policy = "${data.aws_iam_policy_document.execution_role.json}"
}

resource "aws_iam_role" "task_role" {
  name               = "${var.app_name}_ecsTaskRole"
  assume_role_policy = "${data.aws_iam_policy_document.assume_by_ecs.json}"
  tags               = var.tags
}

resource "aws_iam_role_policy" "task_role" {
  role   = "${aws_iam_role.task_role.name}"
  policy = "${data.aws_iam_policy_document.task_role.json}"
}

/*==================================================================================
           5. Service discovery namespace to create service discovery
==================================================================================*/

resource "aws_service_discovery_private_dns_namespace" "service_discovery_ns" {
  name        = "${var.app_name}-ecs"
  description = "service discovery for ecs services "
  vpc         = var.dbmodule_active ? var.db_vpc_id : aws_vpc.ecsinfra-vpc[0].id
  tags        = var.tags
}

/*==================================================================================
                          6. KMS key to encrypt the artifacts
==================================================================================*/

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "artifacts-kms-policy" {
  policy_id = "key-default-1"
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = [
      "kms:*",
    ]
    resources = [
      "*",
    ]
  }
}

resource "aws_kms_key" "key" {
  description = "kms key for artifacts"
  policy      = data.aws_iam_policy_document.artifacts-kms-policy.json
  tags        = var.tags
}

resource "aws_kms_alias" "kms_alias" {
  name          = "alias/${var.app_name}"
  target_key_id = aws_kms_key.key.key_id
}

/*==================================================================================
                          7. S3 Bucket to store the artifacts
==================================================================================*/

# Genrating random string to avoid s3 bucket name duplication.
resource "random_string" "random" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.app_name}-artifacts-${random_string.random.result}"
  force_destroy = true
  tags          = var.tags
}

# Adding ACL to s3 bucket.
resource "aws_s3_bucket_acl" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  acl    = "private"
}

/*==================================================================================
                8. IAM Roles for CodeBuild, CodeDeploy & CodePipeline
==================================================================================*/

# IAM CodeBuild

data "aws_iam_policy_document" "assume_by_codebuild" {
  statement {
    sid     = "AllowAssumeByCodebuild"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.app_name}-codebuild"
  assume_role_policy = "${data.aws_iam_policy_document.assume_by_codebuild.json}"
  tags               = var.tags
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid    = "AllowS3"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowECR"
    effect = "Allow"

    actions = [
      "ecr:*"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AWSKMSUse"
    effect = "Allow"

    actions = [
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:Decrypt"
    ]

    resources = ["*"]
  }

  statement {
    sid       = "AllowECSDescribeTaskDefinition"
    effect    = "Allow"
    actions   = [
        "ecs:List*",
        "ecs:Describe*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowLogging"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  role   = "${aws_iam_role.codebuild.name}"
  policy = "${data.aws_iam_policy_document.codebuild.json}"
}

# IAM CodeDeploy 

data "aws_iam_policy_document" "assume_by_codedeploy" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name               = "${var.app_name}-codedeploy"
  assume_role_policy = "${data.aws_iam_policy_document.assume_by_codedeploy.json}"
  tags               = var.tags
}

data "aws_iam_policy_document" "codedeploy" {
  statement {
    sid    = "AllowLoadBalancingAndECSModifications"
    effect = "Allow"

    actions = [
      "ecs:CreateTaskSet",
      "ecs:DeleteTaskSet",
      "ecs:DescribeServices",
      "ecs:UpdateServicePrimaryTaskSet",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyRule",
      "lambda:InvokeFunction",
      "cloudwatch:DescribeAlarms",
      "sns:Publish",
      "s3:GetObject",
      "s3:GetObjectMetadata",
      "s3:GetObjectVersion"
    ]

    resources = ["*"]
  }
  statement {
    sid    = "KMSAllow"
    effect = "Allow"
    actions = [
      "kms:DescribeKey",
      "kms:Decrypt",
    ]
    resources = [
      aws_kms_key.key.arn
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "*"
    ]
    condition {
      test     = "StringLike"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "codedeploy" {
  role   = "${aws_iam_role.codedeploy.name}"
  policy = "${data.aws_iam_policy_document.codedeploy.json}"
}

# IAM CodePipeline

data "aws_iam_policy_document" "assume_by_codepipeline" {
  statement {
    sid = "AllowAssumeByPipeline"
    effect = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "${var.app_name}-pipeline-ecs-service-role"
  assume_role_policy = "${data.aws_iam_policy_document.assume_by_codepipeline.json}"
  tags               = var.tags
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    sid = "AllowS3"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
    ]

    resources = ["*"]
  }

  statement {
    sid = "AllowECR"
    effect = "Allow"

    actions = ["ecr:DescribeImages"]
    resources = ["*"]
  }

  statement {
    sid = "AllowCodebuild"
    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowCodedepoloy"
    effect = "Allow"

    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision"
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowResources"
    effect = "Allow"

    actions = [
      "elasticbeanstalk:*",
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "cloudwatch:*",
      "s3:*",
      "sns:*",
      "kms:*",
      "cloudformation:*",
      "rds:*",
      "sqs:*",
      "ecs:*",
      "opsworks:*",
      "devicefarm:*",
      "servicecatalog:*",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "*"
    ]
    condition {
      test     = "StringLike"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  role = "${aws_iam_role.codepipeline.name}"
  policy = "${data.aws_iam_policy_document.codepipeline.json}"
}