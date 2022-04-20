output "provisioner_ip" {
  value = metal_device.tink_provisioner.network[0].address
}

output "provisioner_id" {
  value = metal_device.tink_provisioner.id
}

output "provisioner_ssh" {
  value = format("%s.packethost.net", split("-", metal_device.tink_provisioner.id)[0])
}

output "worker_id" {
  value = metal_device.tink_worker.id
}

output "worker_macs" {
  value = local.worker_macs
}

output "worker_sos" {
  value = format("%s@sos.%s.platformequinix.com", metal_device.tink_worker.id, metal_device.tink_worker.deployed_facility)
}
