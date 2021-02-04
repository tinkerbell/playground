output "provisioner_dns_name" {
  value = "${split("-", metal_device.tink_provisioner.id)[0]}.packethost.net"
}

output "provisioner_ip" {
  value = metal_device.tink_provisioner.network[0].address
}

output "worker_mac_addr" {
  value = formatlist("%s", metal_device.tink_worker[*].ports[1].mac)
}

output "worker_sos" {
  value = formatlist("%s@sos.%s.platformequinix.com", metal_device.tink_worker[*].id, metal_device.tink_worker[*].deployed_facility)
}
