resource "azurerm_resource_group" "poc" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "poc" {
  name                = "vnet-haproxy-dns-poc"
  location            = azurerm_resource_group.poc.location
  resource_group_name = azurerm_resource_group.poc.name
  address_space       = ["10.50.0.0/16"]
}

resource "azurerm_subnet" "poc" {
  name                 = "snet-poc"
  resource_group_name  = azurerm_resource_group.poc.name
  virtual_network_name = azurerm_virtual_network.poc.name
  address_prefixes     = ["10.50.1.0/24"]
}

resource "azurerm_private_dns_zone" "demo" {
  name                = "demo.internal"
  resource_group_name = azurerm_resource_group.poc.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "demo" {
  name                  = "demo-internal-link"
  resource_group_name   = azurerm_resource_group.poc.name
  private_dns_zone_name = azurerm_private_dns_zone.demo.name
  virtual_network_id    = azurerm_virtual_network.poc.id
  registration_enabled  = false
}

resource "azurerm_private_dns_a_record" "syntax" {
  name                = "syntax"
  zone_name           = azurerm_private_dns_zone.demo.name
  resource_group_name = azurerm_resource_group.poc.name
  ttl                 = 5
  records             = ["10.50.1.20"]
}

resource "azurerm_public_ip" "haproxy" {
  name                = "pip-haproxy"
  location            = azurerm_resource_group.poc.location
  resource_group_name = azurerm_resource_group.poc.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "haproxy" {
  name                = "nsg-haproxy"
  location            = azurerm_resource_group.poc.location
  resource_group_name = azurerm_resource_group.poc.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HAProxy-Demo"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1520"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "haproxy" {
  name                = "nic-haproxy"
  location            = azurerm_resource_group.poc.location
  resource_group_name = azurerm_resource_group.poc.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.poc.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.50.1.10"
    public_ip_address_id          = azurerm_public_ip.haproxy.id
    primary                       = true
  }
}

resource "azurerm_network_interface_security_group_association" "haproxy" {
  network_interface_id      = azurerm_network_interface.haproxy.id
  network_security_group_id = azurerm_network_security_group.haproxy.id
}

resource "azurerm_network_interface" "backend" {
  name                = "nic-backend"
  location            = azurerm_resource_group.poc.location
  resource_group_name = azurerm_resource_group.poc.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.poc.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.50.1.20"
    primary                       = true
  }

  ip_configuration {
    name                          = "secondary"
    subnet_id                     = azurerm_subnet.poc.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.50.1.21"
    primary                       = false
  }
}

resource "azurerm_linux_virtual_machine" "haproxy" {
  name                            = "haproxy"
  resource_group_name             = azurerm_resource_group.poc.name
  location                        = azurerm_resource_group.poc.location
  size                            = "Standard_D2s_v6"
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.haproxy.id]
  custom_data                     = base64encode(file("${path.module}/cloud-init/haproxy.yaml"))

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "backend" {
  name                            = "backend"
  resource_group_name             = azurerm_resource_group.poc.name
  location                        = azurerm_resource_group.poc.location
  size                            = "Standard_D2s_v6"
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.backend.id]
  custom_data                     = base64encode(file("${path.module}/cloud-init/backend.yaml"))

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
