# OCI infrastructure definition for Aylas.
#
# Related documentation:
# https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/terraformresourcediscovery_topic-Using.htm
# https://registry.terraform.io/providers/oracle/oci/latest/docs
# https://developer.hashicorp.com/terraform/tutorials/oci-get-started
# https://www.digitalocean.com/community/tutorials/how-to-use-ansible-with-terraform-for-configuration-management

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0, < 6.0.0"
    }
  }
}

provider "oci" {
  region              = var.region
  auth                = "SecurityToken"
  config_file_profile = var.oci_profile
}

# ----------------------------- #
# NETWORKS, GATEWAYS AND ROUTES #
# ----------------------------- #

resource "oci_core_vcn" "aylas-net" {
  cidr_blocks = [
    "10.0.0.0/16",
  ]
  display_name   = "aylas-net"
  dns_label      = "aylas"
  compartment_id = var.compartment_id
}

resource "oci_core_subnet" "aylas-one-subnet" {
  cidr_block                 = "10.0.0.0/24"
  display_name               = "aylas-one-subnet"
  dns_label                  = "one"
  prohibit_internet_ingress  = "false"
  prohibit_public_ip_on_vnic = "false"
  security_list_ids = [
    oci_core_vcn.aylas-net.default_security_list_id,
  ]
  vcn_id         = oci_core_vcn.aylas-net.id
  route_table_id = oci_core_vcn.aylas-net.default_route_table_id
  compartment_id = var.compartment_id
}

resource "oci_core_internet_gateway" "gw-aylas-net" {
  display_name   = "aylas-net-internet-gw"
  vcn_id         = oci_core_vcn.aylas-net.id
  compartment_id = var.compartment_id
}

resource "oci_core_default_route_table" "default-aylas-net-route-table" {
  display_name               = "aylas-net-route-table"
  manage_default_resource_id = oci_core_vcn.aylas-net.default_route_table_id
  route_rules {
    network_entity_id = oci_core_internet_gateway.gw-aylas-net.id
    destination       = "0.0.0.0/0"
  }
  compartment_id = var.compartment_id
}

# ---------------------------------------- #
# FIREWALL CONFIGURATIONS (SECURITY LISTS) #
# ---------------------------------------- #

resource "oci_core_default_security_list" "aylas-net-security-list" {
  display_name = "aylas-net-security-list"
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = "false"
  }
  ingress_security_rules {
    description = "In-band SSH management and services traffic"
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = "false"
    tcp_options {
      max = var.ssh_port
      min = var.ssh_port
    }
  }
  # Ingress ICMP control packets
  ingress_security_rules {
    icmp_options {
      code = "4"
      type = "3"
    }
    protocol  = "1"
    source    = "0.0.0.0/0"
    stateless = "false"
  }
  ingress_security_rules {
    icmp_options {
      code = "-1"
      type = "3"
    }
    protocol  = "1"
    source    = "10.0.0.0/16"
    stateless = "false"
  }
  ingress_security_rules {
    description = "Minecraft server ingress traffic"
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = "true"
    tcp_options {
      max = "25545"
      min = "25545"
    }
  }
  dynamic "ingress_security_rules" {
    # Cloudflare IP ranges: https://www.cloudflare.com/ips-v4
    for_each = [
      "173.245.48.0/20", "103.21.244.0/22", "103.22.200.0/22", "103.31.4.0/22", "141.101.64.0/18",
      "108.162.192.0/18", "190.93.240.0/20", "188.114.96.0/20", "197.234.240.0/22", "198.41.128.0/17",
      "162.158.0.0/15", "104.16.0.0/13", "104.24.0.0/14", "172.64.0.0/13", "131.0.72.0/22"
    ]
    content {
      description = "Web map HTTP server ingress traffic"
      protocol    = "6"
      source      = ingress_security_rules.value
      stateless   = "true"
      tcp_options {
        max = "8123"
        min = "8123"
      }
    }
  }
  manage_default_resource_id = oci_core_vcn.aylas-net.default_security_list_id
  compartment_id             = var.compartment_id
}

# --------- #
# INSTANCES #
# --------- #

resource "oci_core_instance" "aylas-one" {
  display_name = "aylas-one"

  # ARM Ampere® Altra™ instance
  shape = "VM.Standard.A1.Flex"
  shape_config {
    memory_in_gbs = "8"
    ocpus         = "2"
  }
  source_details {
    boot_volume_size_in_gbs = "50"
    boot_volume_vpus_per_gb = "120"
    source_id               = var.server_image
    source_type             = "image"
  }
  launch_options {
    boot_volume_type                    = "PARAVIRTUALIZED"
    firmware                            = "UEFI_64"
    is_consistent_volume_naming_enabled = "true"
    network_type                        = "PARAVIRTUALIZED"
    remote_data_volume_type             = "PARAVIRTUALIZED"
  }
  create_vnic_details {
    assign_public_ip       = "true"
    display_name           = "aylas-one-vnic"
    hostname_label         = "aylas-one"
    private_ip             = "10.0.0.100"
    skip_source_dest_check = "false"
    subnet_id              = oci_core_subnet.aylas-one-subnet.id
  }
  availability_domain = var.availability_domain
  metadata = {
    "ssh_authorized_keys" = var.master_user_public_ssh_key
    "user_data"           = base64encode(templatefile("data/cloud-config", { ssh_port = var.ssh_port }))
  }
  compartment_id = var.compartment_id

  provisioner "local-exec" {
    command = "printf -- '${var.master_user_private_ssh_key}' > /tmp/${self.create_vnic_details[0].hostname_label}-master-key && chmod go-rwx /tmp/${self.create_vnic_details[0].hostname_label}-master-key"
  }

  provisioner "local-exec" {
    command = "ansible-playbook -e tf_provisioner_run=true -i '${self.public_ip}:${var.ssh_port},' -u master --private-key /tmp/${self.create_vnic_details[0].hostname_label}-master-key '${self.create_vnic_details[0].hostname_label}.ansible.yml'"
  }
}

output "aylas-one-ip" {
  value       = oci_core_instance.aylas-one.public_ip
  description = "aylas-one server public IPv4 address"
}
