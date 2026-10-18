# Windows Server 2025 golden image: Git + Google Chrome + IIS preinstalled.
source "azure-arm" "windows" {
  use_azure_cli_auth = true

  location = var.location
  vm_size  = var.vm_size
  os_type  = "Windows"

  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2025-datacenter-g2"

  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "15m"
  winrm_username = "packer"

  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = var.gallery_resource_group
    gallery_name         = var.gallery_name
    image_name           = "windows-2025"
    image_version        = var.image_version
    replication_regions  = [var.location]
    storage_account_type = "Standard_LRS"
  }

  azure_tags = {
    built_by      = "packer"
    image_version = var.image_version
    tools         = "git,chrome,iis"
  }
}

build {
  name    = "windows"
  sources = ["source.azure-arm.windows"]

  # Install and verify: IIS, Git, Google Chrome
  provisioner "powershell" {
    script           = "scripts/windows-setup.ps1"
    environment_vars = ["IMAGE_VERSION=${var.image_version}"]
  }

  # Clear any pending reboot before generalizing
  provisioner "windows-restart" {
    restart_timeout = "10m"
  }

  # Sysprep / generalize (must be last)
  provisioner "powershell" {
    inline = [
      "while ((Get-Service RdAgent).Status -ne 'Running') { Start-Sleep -s 5 }",
      "while ((Get-Service WindowsAzureGuestAgent).Status -ne 'Running') { Start-Sleep -s 5 }",
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit /mode:vm",
      "while($true) { $s = (Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State).ImageState; if($s -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $s; Start-Sleep -s 10 } else { break } }"
    ]
  }
}
