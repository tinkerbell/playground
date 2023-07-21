# Configure the Equinix Metal Provider.
terraform {
  required_providers {
    metal = {
      source  = "equinix/metal"
      version = "3.2.0"
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

# Create a new VLAN in datacenter
resource "metal_vlan" "provisioning_vlan" {
  description = "provisioning_vlan"
  metro       = var.metro
  project_id  = var.project_id
}

# Create a device and add it to tf_project_1
resource "metal_device" "tink_worker" {
  hostname         = "tink-worker"
  plan             = var.device_type
  metro            = var.metro
  operating_system = "custom_ipxe"
  ipxe_script_url  = "https://boot.netboot.xyz"
  always_pxe       = "true"
  billing_cycle    = "hourly"
  project_id       = var.project_id
}

resource "metal_port" "tink_worker_bond0" {
  port_id = [for p in metal_device.tink_worker.ports : p.id if p.name == "bond0"][0]
  layer2  = true
  bonded  = false
  #  vlan_ids = [metal_vlan.provisioning_vlan.id] 
  # Can't do this: │ Error: vlan assignment batch could not be created: POST https://api.equinix.com/metal/v1/ports/b0bdf6d8-589e-4988-9000-9f49c97a54e1/vlan-assignments/batches: 422 Can't assign VLANs to port b0bdf6d8-589e-4988-9000-9f49c97a54e1, the port is configured for Layer 3 mode., Port b0bdf6d8-589e-4988-9000-9f49c97a54e1 cannot be assigned to VLANs., Bond disabled 
}

# Attach VLAN to worker
resource "metal_port" "tink_worker_eth0" {
  depends_on = [metal_port.tink_worker_bond0]
  port_id    = [for p in metal_device.tink_worker.ports : p.id if p.name == "eth0"][0]
  #layer2     = true 
  # TODO(displague) the terraform provider is not permitting this, perhaps a bug in the provider validation
  # layer2 flag can be set only for bond ports
  bonded   = false
  vlan_ids = [metal_vlan.provisioning_vlan.id]
  // vxlan_ids = [1000]
}

# Create a device and add it to tf_project_1
resource "metal_device" "tink_provisioner" {
  hostname         = "tink-provisioner"
  plan             = var.device_type
  metro            = var.metro
  operating_system = "ubuntu_20_04"
  billing_cycle    = "hourly"
  project_id       = var.project_id
  user_data        = data.cloudinit_config.setup.rendered
}

# Provisioners eth1 (unbonded) is attached to the provisioning VLAN
resource "metal_port" "eth1" {
  port_id  = [for p in metal_device.tink_provisioner.ports : p.id if p.name == "eth1"][0]
  bonded   = false
  vlan_ids = [metal_vlan.provisioning_vlan.id]
}

data "archive_file" "compose" {
  type        = "zip"
  source_dir  = "${path.module}/../../stack/compose"
  output_path = "${path.module}/compose.zip"
}

locals {
  compose_zip = data.archive_file.compose.output_size > 0 ? filebase64("${path.module}/compose.zip") : ""
  worker_macs = flatten([for wp in metal_device.tink_worker[*].ports[*] : [for p in wp : p.mac if p.name == "eth0"]])
}

data "cloudinit_config" "setup" {
  depends_on = [
    data.archive_file.compose,
  ]
  gzip          = false # not supported on Equinix Metal
  base64_encode = false # not supported on Equinix Metal

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-config.cfg", {
      COMPOSE_ZIP = local.compose_zip
      SETUPSH     = filebase64("${path.module}/setup.sh")
      ENVFILE     = filebase64("${path.module}/.env")
      WORKER_MAC  = local.worker_macs[0]
    })
  }
}
