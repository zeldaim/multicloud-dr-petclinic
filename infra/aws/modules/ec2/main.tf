# =============================================================================
# EC2 Module
# Bastion Host 및 Management Server
# =============================================================================

# -----------------------------------------------------------------------------
# TLS Private Key for SSH
# -----------------------------------------------------------------------------
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh.public_key_openssh

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-keypair"
    }
  )
}

# 프라이빗 키를 로컬에 저장
resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${var.key_output_path}/${var.key_name}.pem"
  file_permission = "0400"
}

# -----------------------------------------------------------------------------
# Bastion Host
# 위치: Public Subnet A
# Public IP 할당됨
# -----------------------------------------------------------------------------
resource "aws_instance" "bastion" {
  ami                         = var.ec2_ami_id != null ? var.ec2_ami_id : var.ubuntu_ami_id
  instance_type               = var.bastion_instance_type
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = aws_key_pair.generated.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.bastion_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 강제
    http_put_response_hop_limit = 1
  }

  tags = var.bastion_tags

  # 간단한 초기화 스크립트
  user_data = var.bastion_user_data
}

# -----------------------------------------------------------------------------
# Management Server
# 위치: App Private Subnet A (보안을 위해 Private에 배치)
# Bastion을 통해서만 SSH 접근 가능
# -----------------------------------------------------------------------------
resource "aws_instance" "mgmt" {
  ami                    = var.ec2_ami_id != null ? var.ec2_ami_id : var.ubuntu_ami_id
  instance_type          = var.mgmt_instance_type
  subnet_id              = var.app_private_subnet_ids[0]
  vpc_security_group_ids = [var.mgmt_sg_id]
  key_name               = aws_key_pair.generated.key_name
  iam_instance_profile   = var.mgmt_iam_instance_profile_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.mgmt_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 강제
    http_put_response_hop_limit = 2          # Docker 컨테이너에서 접근 가능하도록
  }

  tags = var.mgmt_tags

  # User Data 스크립트 (외부 파일 사용)
  user_data = var.mgmt_user_data

  depends_on = [var.nat_gateway_dependency]
}

