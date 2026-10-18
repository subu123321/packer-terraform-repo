# Ubuntu 24.04 golden image: Git + Python + Docker preinstalled.
source "azure-arm" "ubuntu" {
  use_azure_cli_auth = true   # uses the az login done by the AzureCLI@2 pipeline task

  location = var.location
  vm_size  = var.vm_size
  os_type  = "Linux"

  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "server"

  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = var.gallery_resource_group
    gallery_name         = var.gallery_name
    image_name           = "ubuntu-2404"
    image_version        = var.image_version
    replication_regions  = [var.location]
    storage_account_type = "Standard_LRS"
  }

  azure_tags = {
    built_by      = "packer"
    image_version = var.image_version
    tools         = "git,python,docker"
  }
}

build {
  name    = "ubuntu"
  sources = ["source.azure-arm.ubuntu"]

  # Install and verify: git, python3 (+pip, venv), docker engine (+compose, buildx)
  provisioner "shell" {
    script           = "scripts/ubuntu-setup.sh"
    environment_vars = ["IMAGE_VERSION=${var.image_version}"]
    execute_command  = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
  }

  # Generalize the VM (must be last)
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    inline_shebang = "/bin/sh -x"
  }
}
