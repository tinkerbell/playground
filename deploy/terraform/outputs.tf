output "provisioner_ip" {
  value = metal_device.tink_provisioner.network[0].address
}

output "worker_sos" {
  value = formatlist("%s@sos.%s.platformequinix.com", metal_device.tink_worker[*].id, metal_device.tink_worker.deployed_facility)
}
