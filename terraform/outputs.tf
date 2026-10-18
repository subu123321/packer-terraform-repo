output "ubuntu_vms" {
  value = {
    for i, ip in azurerm_public_ip.ubuntu[*].ip_address :
    "ubuntu-${i + 1}" => {
      public_ip = ip
      ssh       = "ssh ${var.admin_username}@${ip}"
    }
  }
}

output "windows_vms" {
  value = {
    for i, ip in azurerm_public_ip.windows[*].ip_address :
    "windows-${i + 1}" => {
      public_ip = ip
      url       = "http://${ip}"
      rdp       = "mstsc /v:${ip}"
    }
  }
}

output "ubuntu_image_version_used" {
  value = local.use_ubuntu ? data.azurerm_shared_image_version.ubuntu[0].name : null
}

output "windows_image_version_used" {
  value = local.use_windows ? data.azurerm_shared_image_version.windows[0].name : null
}

output "admin_username" {
  value = var.admin_username
}

output "admin_password" {
  value     = random_password.admin.result
  sensitive = true
}
