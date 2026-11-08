# =============================================================================
# EC2 Module Variables
# =============================================================================

variable "name_prefix" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}

variable "key_name" {
  description = "EC2 Key Pair 이름"
  type        = string
}

variable "key_output_path" {
  description = "SSH 키 파일 출력 경로"
  type        = string
  default     = "./mykey"
}

variable "ec2_ami_id" {
  description = "EC2 AMI ID (null이면 최신 AMI 자동 조회)"
  type        = string
  default     = null
}

variable "ubuntu_ami_id" {
  description = "Ubuntu AMI ID (data source에서 조회한 값)"
  type        = string
}

variable "bastion_instance_type" {
  description = "Bastion Host 인스턴스 타입"
  type        = string
}

variable "mgmt_instance_type" {
  description = "Management Server 인스턴스 타입"
  type        = string
}

variable "bastion_volume_size" {
  description = "Bastion Host 루트 볼륨 크기 (GB)"
  type        = number
  default     = 20
}

variable "mgmt_volume_size" {
  description = "Management Server 루트 볼륨 크기 (GB)"
  type        = number
  default     = 50
}

variable "public_subnet_ids" {
  description = "Public Subnet IDs"
  type        = list(string)
}

variable "app_private_subnet_ids" {
  description = "App Private Subnet IDs"
  type        = list(string)
}

variable "bastion_sg_id" {
  description = "Bastion Security Group ID"
  type        = string
}

variable "mgmt_sg_id" {
  description = "Management Server Security Group ID"
  type        = string
}

variable "mgmt_iam_instance_profile_name" {
  description = "Management Server IAM Instance Profile Name"
  type        = string
}

variable "bastion_tags" {
  description = "Bastion Host 태그"
  type        = map(string)
  default     = {}
}

variable "mgmt_tags" {
  description = "Management Server 태그"
  type        = map(string)
  default     = {}
}

variable "bastion_user_data" {
  description = "Bastion Host User Data 스크립트"
  type        = string
  default     = ""
}

variable "mgmt_user_data" {
  description = "Management Server User Data 스크립트"
  type        = string
}

variable "nat_gateway_dependency" {
  description = "NAT Gateway 의존성 (depends_on용)"
  type        = any
  default     = null
}

