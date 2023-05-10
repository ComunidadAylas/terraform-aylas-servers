variable "compartment_id" {
  description = "OCID. Retrieve by clicking on the profile icon in the far top right of the OCI console and selecting \"Tenancy: YourUsername\" from the dropdown menu."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "OCI tenancy region"
  type        = string
  default     = "eu-madrid-1"
}

variable "availability_domain" {
  description = "OCI availability domain for instances"
  type        = string
  default     = "xbrv:EU-MADRID-1-AD-1"
}

variable "oci_profile" {
  description = "OCI CLI configuration profile"
  type        = string
  default     = "terraform-aylas"
}

variable "server_image" {
  description = "Base Linux image for the instance"
  type        = string
  # Ubuntu 22.04 Minimal (AArch64, 2023.04.18-0)
  # List of images available at https://docs.oracle.com/en-us/iaas/images/
  default = "ocid1.image.oc1.eu-madrid-1.aaaaaaaally4556huuq5blmvbv2flxqeofmew5qo65wks36ngixpogr76oka"
}

variable "master_user_public_ssh_key" {
  description = "Public SSH key for the master (administrator) user"
  type        = string
}

variable "master_user_private_ssh_key" {
  description = "Private SSH key for the master (administrator) user"
  type        = string
  sensitive   = true
}

variable "ssh_port" {
  description = "The SSH port that the instance will listen on. Setting it to something different than 22 avoids being targeted by mass scans"
  type        = number
  default     = 22
}
