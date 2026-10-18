variable "location" {
  type    = string
  default = "uaenorth"
}

variable "prefix" {
  type    = string
  default = "imglab"
}

variable "gallery_resource_group" {
  type = string
}

variable "gallery_name" {
  type = string
}

variable "ubuntu_image_name" {
  type    = string
  default = "ubuntu-2404"
}

variable "windows_image_name" {
  type    = string
  default = "windows-2025"
}

# "latest" picks the newest published version. Or pin e.g. "1.0.123".
variable "image_version" {
  type    = string
  default = "latest"
}

variable "ubuntu_count" {
  type    = number
  default = 1
  validation {
    condition     = var.ubuntu_count >= 0 && var.ubuntu_count <= 10
    error_message = "ubuntu_count must be between 0 and 10."
  }
}

variable "windows_count" {
  type    = number
  default = 1
  validation {
    condition     = var.windows_count >= 0 && var.windows_count <= 10
    error_message = "windows_count must be between 0 and 10."
  }
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "admin_username" {
  type    = string
  default = "labadmin"
}

# LAB WARNING: "*" exposes SSH/RDP/HTTP to the internet. Set to your public IP/32.
variable "allowed_source_cidr" {
  type    = string
  default = "*"
}
