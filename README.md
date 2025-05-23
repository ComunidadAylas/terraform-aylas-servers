<div align="center">
<img src="https://avatars.githubusercontent.com/u/38165202" alt="OptiVorbis logo" width="33%">
<h1>🏗️ terraform-aylas-servers</h1>

<i>Terraform and Ansible artifacts to manage the Aylas Community server
infrastructure configuration, which includes a Minecraft server hosted on Always
Free Oracle Cloud Infrastructure instances.</i>

<a href="https://github.com/ComunidadAylas/terraform-aylas-servers/actions?query=workflow%3AStatic%20analysis"><img alt="Static analysis workflow status"
src="https://github.com/ComunidadAylas/terraform-aylas-servers/actions/workflows/static-analysis.yml/badge.svg"></a>
</div>

This repository contains the definition files for the production Aylas Community
server infrastructure configuration, following an [Infrastructure as
Code](https://www.redhat.com/en/topics/automation/what-is-infrastructure-as-code-iac)
(IaC) approach.

With this approach, we aim to follow established technical best practices and
improve the consistency, reliability, traceability, deployment speed and
disaster recovery procedures of our infrastructure compared to manual processes.
In addition, we seek to to bring our development and server management forces
closer together, fostering
[DevOps](https://www.redhat.com/en/topics/devops)-inspired workflows.

We are releasing our configuration to the public to provide insight into what
makes our community tick, and potentially inspire others. Feel free to suggest
improvements, or use parts of our configuration in your own deployments!

# ✨ Highlights

- 🏗️ Leverages [Terraform](https://www.terraform.io/) and
  [Ansible](https://www.ansible.com/) to manage our [Oracle Cloud
  Infrastructure](https://www.oracle.com/cloud/) from the sign-up on OCI to the
  moment our services are up, with minimal manual intervention.
- 🖥️ Sets up a 24/7 **[Purpur](https://purpurmc.org/) Minecraft server using
  the recommended [brucethemoose's state of the art JVM
  flags](https://github.com/brucethemoose/Minecraft-Performance-Flags-Benchmark)**
  on a minimal, standard **ARM Ubuntu 24.04 virtual machine** (a.k.a. instance).
  [Oracle GraalVM](https://www.graalvm.org/downloads/) (formerly Oracle GraalVM
  Enterprise Edition) is used, leveraging its top-tier compiler based on JVMCI,
  which generates significantly better optimized code than OpenJDK's C2 for some
  workloads.
- 💾 Automated [**3-2-1 backup
  strategy**](https://www.backblaze.com/blog/the-3-2-1-backup-strategy/) powered
  by [rustic](https://rustic.cli.rs/):
  - We store the live data, a local backup repository and a remote backup
    repository on [MEGA](https://mega.nz/).
  - Backup repositories are compressed with Zstd at level 20, and encrypted with
    a symmetric cipher.
  - The server is automatically restarted every few days to do a synthetic full
    backup (i.e., logically full backups implemented through forever-incremental
    backup blobs that get assembled into snapshots) of its files. Before
    updating to a new Minecraft version, a special backup that does not get
    automatically deleted is made. Otherwise, backup snapshots are automatically
    deleted after a few months, and the backup repositories pruned to claim
    storage space back.
  - A notification is sent to a Discord channel via
    [webhooks](https://discord.com/developers/docs/resources/webhook) when a
    backup is done. (This can be disabled by not defining the webhook URL in the
    Ansible playbooks.)
- 👌 Easy, user-friendly and secure **remote management over SSH**:
  - Server applications (for now, the Purpur server) run on a **dedicated and
    unprivileged user**, with SSH forwarding and SFTP access disabled. Shell
    access is restricted to a locked-down
    [`tmux`](https://github.com/tmux/tmux/wiki) session that only allows
    interaction with the server console, providing an experience similar to
    interacting with a local server console window. Unexpected critical server
    files modifications are prevented via the [immutable filesystem
    attribute](https://man7.org/linux/man-pages/man1/chattr.1.html).
  - A secondary account with only SFTP access is provided to manage server
    files. These SFTP sessions are
    [jailed](https://en.wikipedia.org/wiki/Chroot) to the server directory, so
    that they see a clean directory hierarchy free from system files. The
    directory can be mounted as a filesystem for quick access from Linux,
    Windows, BSD and macOS clients by using `rclone`, SSHFS, or
    [SSHFS-Win](https://github.com/winfsp/sshfs-win).
  - The server console is extended with a server controller that handles
    interactively starting a server after it stops, restoring backups, and
    updating or backing up the server files.
  - Secure SSH login keys are automatically generated, set up and copied to the
    local `login_keys` directory during initial provisioning. Password
    authentication is disabled.
  - We make it easy to change the SSH server port during deployment, which is an
    effective defense against the log spam and waste of CPU cycles caused by the
    mass SSH scans that plague the Internet with a minimal impact on usability
    and availability.
- 🛡️ **Game server hardening** based on [**AppArmor**](https://apparmor.net/),
  which implements mandatory access control mechanisms used to prevent
  unexpected server behavior in an easy-to-manage manner.
- 🆕 **Automated** daily system and server software **updates**.
- 🚨 The `ttyAMA0` serial console is set up for [**out-of-band
  management**](https://en.wikipedia.org/wiki/Out-of-band_management), ensuring
  that trusted parties can control the instance using the OCI web panel even if
  SSH connectivity is lost.
- 📊 Per-service **disk quotas** to guarantee the expected distribution of disk
  space and mitigate the impact of errant applications.
- 🌐 **IPv6 support** for future-proofing and letting every client use the IP
  stack version that works best for them.
- 🔝 **Static analysis** checks are executed on each push by GitHub Actions
  runners to guarantee code quality.
- 🙌 Due to the usage of vendor-agnostic IaC tools and standard Linux software,
  **we avoid cloud vendor lock-in**. It should be easy to port this
  configuration to other cloud environments.
- 🤑 Thanks to OCI's generous [Always Free
  tier](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm),
  you can get all of this for free!*

<sup><sub>\* If you are over legal age, and willing to give Oracle accurate contact
information and your credit card number during registration. Virtual cards are
not accepted. Always Free resources may not be always available in all regions,
and they can only be deployed to your home region, which is chosen when signing
up and can't be changed. Oracle ~~is evil~~ may change these conditions in the
future. We don't expect to contact their support for anything. Abusive usage of
these resources may cause account termination. Apart from than that, we're not
aware of any other fine print in their conditions.</sup></sub>

# 📥 Getting started

After cloning the repository, run `terrashell.sh` on a Linux-like environment
with `python3` and `pip` available (Linux, WSL) to set up a temporary [virtual
environment](https://docs.python.org/3/library/venv.html) where Terraform,
Ansible and the OCI CLI will be installed. This environment is automatically
cleaned up on exit. If you are using another operating system, you can set up
this environment manually. From here you can **run `terraform apply` to deploy
and provision the infrastructure in less than 10 minutes**, in addition to other
Terraform and Ansible commands.

## ✏️ Variables and secrets

For obvious reasons, the default values of some variables may not be suitable
for your particular scenario (i.e., the OCI tenancy region), and some pieces of
configuration are stored as [sensitive Terraform
variables](https://developer.hashicorp.com/terraform/language/values/variables#suppressing-values-in-cli-output)
or [Ansible Vault encrypted
variables](https://docs.ansible.com/ansible/latest/vault_guide/index.html).
These variables are defined at the `*.ansible.yml` and `variables.tf` files.
**You must review these variables prior to your first deployment and change
their values accordingly**.

## ⚙️ Development environment

We recommend using Visual Studio Code with the extensions recommended by this
repository because they provide a good development experience, with code
analysis and coding assistance features (lints, autocompletion...). However, you
can use other text editors if you wish.

# 📁 Project structure

`main.tf` is the entrypoint for the infrastructure definition, which invokes
Ansible playbooks (files with `.ansible.yml` extension) to provision instances
with the specific software configuration. The playbooks leverage reusable roles
defined at the `roles` directory, which execute related configuration tasks. As
usual with Ansible, it is possible to run playbooks on already provisioned
machines to apply new configurations.

# ✨ Contributing

Pull requests are accepted. Feel free to contribute if you can improve some
aspect of our server infrastructure!

# ⚖️ License

[MIT](https://opensource.org/license/mit/) © Alejandro González
