# Configure the Packet Provider.
terraform {
  required_providers {
    metal = {
      source  = "equinix/metal"
      version = "3.1.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 2.1.2"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.1.2"
    }
  }
}

provider "metal" {
  auth_token = var.metal_api_token
}

# Create a new VLAN in datacenter "ewr1"
resource "metal_vlan" "provisioning_vlan" {
  description = "provisioning_vlan"
  facility    = var.facility
  project_id  = var.project_id
}

# Create a device and add it to tf_project_1
resource "metal_device" "tink_worker" {
  hostname         = "tink-worker"
  plan             = var.device_type
  facilities       = [var.facility]
  operating_system = "custom_ipxe"
  ipxe_script_url  = "https://boot.netboot.xyz"
  always_pxe       = "true"
  billing_cycle    = "hourly"
  project_id       = var.project_id
}

resource "metal_device_network_type" "tink_worker_network_type" {
  device_id = metal_device.tink_worker.id
  type      = "layer2-individual"
}

# Attach VLAN to worker
resource "metal_port_vlan_attachment" "worker" {
  depends_on = [metal_device_network_type.tink_worker_network_type]

  device_id = metal_device.tink_worker.id
  port_name = "eth0"
  vlan_vnid = metal_vlan.provisioning_vlan.vxlan
}


# Create a device and add it to tf_project_1
resource "metal_device" "tink_provisioner" {
  hostname         = "tink-provisioner"
  plan             = var.device_type
  facilities       = [var.facility]
  operating_system = "ubuntu_20_04"
  billing_cycle    = "hourly"
  project_id       = var.project_id
  user_data        = data.cloudinit_config.setup.rendered
}

resource "metal_device_network_type" "tink_provisioner_network_type" {
  device_id = metal_device.tink_provisioner.id
  type      = "hybrid"
}

# Attach VLAN to provisioner
resource "metal_port_vlan_attachment" "provisioner" {
  depends_on = [metal_device_network_type.tink_provisioner_network_type]
  device_id  = metal_device.tink_provisioner.id
  port_name  = "eth1"
  vlan_vnid  = metal_vlan.provisioning_vlan.vxlan
}

data "archive_file" "compose" {
  type        = "zip"
  source_dir  = "${path.module}/../compose"
  output_path = "${path.module}/compose.zip"
}

data "cloudinit_config" "setup" {
  depends_on = [
    data.archive_file.compose,
    // resource.null_resource.setup
  ]
  gzip          = false # not supported on Equinix Metal
  base64_encode = false # not supported on Equinix Metal

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/setup.sh")
  }
  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-config.cfg", {
      COMPOSE_ZIP    = filebase64("${path.module}/compose.zip")
      WORKER_MAC     = metal_device.tink_worker.ports[1].mac
      PROVISIONER_IP = metal_device.tink_provisioner.network[0].address
    })
  }
}
