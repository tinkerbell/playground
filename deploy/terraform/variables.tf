variable "metal_api_token" {
  description = "Equinix Metal user api token"
  type        = string
}

variable "project_id" {
  description = "Project ID"
  type        = string
}

variable "metro" {
  description = "Equinix Metal metro to provision in"
  type        = string
  default     = "sv"
}

variable "device_type" {
  type        = string
  description = "Type of device to provision"
  default     = "c3.small.x86"
}

variable "use_ssh_agent" {
  type        = bool
  description = "Use ssh agent to connect to provisioner machine"
  default     = false
}

variable "ssh_private_key" {
  type        = string
  description = "ssh private key file to use"
  default     = "~/.ssh/id_rsa"
}
