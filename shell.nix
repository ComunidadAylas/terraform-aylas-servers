let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-25.05";
  pkgs = import nixpkgs {
    config = { };
    overlays = [ ];
  };
in
pkgs.mkShellNoCC {
  packages = with pkgs; [
    opentofu
    python312Packages.ansible-core
    ansible-lint
    oci-cli

    nixfmt-rfc-style
    nil
  ];

  OCI_TENANCY_REGION = "eu-madrid-1";

  shellHook = ''
    set -eu

    echo '> Installing Ansible Galaxy artifacts...'
    ansible-galaxy install -r requirements.yml

    if [ -z "$CI" ]; then
      echo
      echo '> Authenticating with OCI...'
      oci session authenticate --profile-name terraform-aylas --region "$OCI_TENANCY_REGION"

      echo
      echo '> Initializing OpenTofu...'
      tofu init

      echo
      echo 'Commands cheatsheet:'
      echo ' - tofu fmt'
      echo ' - tofu validate'
      echo ' - tofu apply -auto-approve (create and start instances)'
      echo ' - tofu destroy (stop and tear down instances)'
      echo ' - tofu output aylas-one-ipv4 (get the aylas-one server public IPv4 address)'
      echo " - oci session authenticate --profile-name terraform-aylas --region $OCI_TENANCY_REGION (authenticate with OCI again)"
    fi
  '';
}
