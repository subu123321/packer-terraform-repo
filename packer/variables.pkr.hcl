variable "subscription_id" {
  type        = string
  description = "Set by the pipeline via PKR_VAR_subscription_id"
}

variable "location" {
  type    = string
  default = "uaenorth"
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "gallery_resource_group" {
  type    = string
  default = "rg-imagefactory"
}

variable "gallery_name" {
  type    = string
  default = "acg_imagefactory"
}

# Must be x.y.z. The pipeline passes 1.0.<BuildId>
variable "image_version" {
  type    = string
  default = "1.0.0"
}
