locals {
  use_ubuntu  = var.ubuntu_count > 0
  use_windows = var.windows_count > 0
}

# ---------- Generated admin password (lab convenience) ----------
resource "random_password" "admin" {
  length           = 20
  special          = true
  override_special = "!#%*-_=+"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

# ---------- Images produced by Packer (only looked up when that OS is requested) ----------
data "azurerm_shared_image_version" "ubuntu" {
  count               = local.use_ubuntu ? 1 : 0
  name                = var.image_version
  image_name          = var.ubuntu_image_name
  gallery_name        = var.gallery_name
  resource_group_name = var.gallery_resource_group
}

data "azurerm_shared_image_version" "windows" {
  count               = local.use_windows ? 1 : 0
  name                = var.image_version
  image_name          = var.windows_image_name
  gallery_name        = var.gallery_name
  resource_group_name = var.gallery_resource_group
}

# ---------- Network ----------
resource "azurerm_resource_group" "vm" {
  name     = "rg-${var.prefix}-vms"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.prefix}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  address_space       = ["10.20.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "snet-vms"
  resource_group_name  = azurerm_resource_group.vm.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.prefix}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_source_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-rdp"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.allowed_source_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.allowed_source_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ---------- Ubuntu VMs ----------
resource "azurerm_public_ip" "ubuntu" {
  count               = var.ubuntu_count
  name                = "pip-${var.prefix}-ubuntu-${count.index + 1}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "ubuntu" {
  count               = var.ubuntu_count
  name                = "nic-${var.prefix}-ubuntu-${count.index + 1}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ubuntu[count.index].id
  }
}

resource "azurerm_linux_virtual_machine" "ubuntu" {
  count                           = var.ubuntu_count
  name                            = "vm-${var.prefix}-ubuntu-${count.index + 1}"
  resource_group_name             = azurerm_resource_group.vm.name
  location                        = azurerm_resource_group.vm.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = random_password.admin.result
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.ubuntu[count.index].id]
  source_image_id                 = data.azurerm_shared_image_version.ubuntu[0].id

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  tags = { image_version = data.azurerm_shared_image_version.ubuntu[0].name }
}

# ---------- Windows VMs ----------
resource "azurerm_public_ip" "windows" {
  count               = var.windows_count
  name                = "pip-${var.prefix}-win-${count.index + 1}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "windows" {
  count               = var.windows_count
  name                = "nic-${var.prefix}-win-${count.index + 1}"
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.windows[count.index].id
  }
}

resource "azurerm_windows_virtual_machine" "windows" {
  count                 = var.windows_count
  name                  = "vm-${var.prefix}-win-${count.index + 1}"
  computer_name         = format("winlab%02d", count.index + 1) # max 15 chars
  resource_group_name   = azurerm_resource_group.vm.name
  location              = azurerm_resource_group.vm.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  admin_password        = random_password.admin.result
  network_interface_ids = [azurerm_network_interface.windows[count.index].id]
  source_image_id       = data.azurerm_shared_image_version.windows[0].id

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  tags = { image_version = data.azurerm_shared_image_version.windows[0].name }
}
