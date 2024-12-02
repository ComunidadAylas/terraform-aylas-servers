#!/bin/sh -eu

# renovate: datasource=docker depName=hashicorp/terraform versioning=docker
readonly TERRAFORM_VERSION=1.10.0
readonly OCI_TENANCY_REGION=eu-madrid-1

WORKDIR="$(mktemp --tmpdir --directory terraform-aylas.XXX)"
readonly WORKDIR

trap 'rm -rf "$WORKDIR"; rm -rf ~/.oci' EXIT INT TERM

export PATH="$WORKDIR:$PATH"

echo '> Setting up Python virtual environment...'
python3 -m venv "$WORKDIR"/venv
# shellcheck disable=SC1091
. "$WORKDIR"/venv/bin/activate
pip install poetry
poetry install

echo
echo "> Downloading Terraform v$TERRAFORM_VERSION..."
curl -o "$WORKDIR"/terraform.zip \
	"https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_$(dpkg-architecture -q DEB_HOST_ARCH).zip"
unzip "$WORKDIR"/terraform.zip terraform -d "$WORKDIR"
rm "$WORKDIR"/terraform.zip
chmod +x "$WORKDIR"/terraform

echo
echo '> Authenticating with OCI...'
oci session authenticate --profile-name terraform-aylas --region "$OCI_TENANCY_REGION"

echo
echo '> Initializing Terraform...'
terraform init

echo
echo 'Commands cheatsheet:'
echo ' - terraform fmt'
echo ' - terraform validate'
echo ' - terraform apply -auto-approve (create and start instances)'
echo ' - terraform destroy (stop and tear down instances)'
echo ' - terraform output aylas-one-ipv4 (get the aylas-one server public IPv4 address)'
echo " - oci session authenticate --profile-name terraform-aylas --region $OCI_TENANCY_REGION (authenticate with OCI again)"

exec "$SHELL"
