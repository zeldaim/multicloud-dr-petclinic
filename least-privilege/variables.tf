variable "project_name" {
  description = "기존 dev 환경과 같은 이름 접두어"
  type        = string
  default     = "petclinic"
}

variable "ssm_path_prefix" {
  description = "관리 서버가 읽을 SSM 파라미터 경로 (앞뒤 / 포함)"
  type        = string
  default     = "/petclinic/"
}

variable "deployer_session_seconds" {
  description = "배포 역할을 넘겨받았을 때 임시 키 유효 시간(초)"
  type        = number
  default     = 3600
}
