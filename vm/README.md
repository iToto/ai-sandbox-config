# Claude Code Sandbox — VM Edition

A KVM/libvirt virtual machine that replicates the Docker sandbox (same packages,
Oh My Zsh + Powerlevel10k, tmux, Claude Code) but with VM-level isolation instead
of container isolation: separate kernel, separate virtual NIC, no shared
namespaces with the host.

## Why a VM instead of the container

A VM gives you a real boundary between sandbox and host — no shared kernel, no
container-escape class of bugs, and the isolation is enforced by hardware
virtualization (KVM) rather than namespaces/cgroups.

## Files

| File | Description |
|---|---|
| `packer/sandbox.pkr.hcl` | Packer template that builds the VM image (the VM equivalent of `Dockerfile`) |
| `packer/provision.sh` | Provisioning script run inside the image during build |
| `packer/http/user-data` | cloud-init autoinstall answers for unattended Ubuntu Server install |
| `libvirt-network.xml` | Defines an isolated NAT network (`sandbox-net`) for the VM |
| `network-isolation.sh` | Blocks the VM from reaching your LAN/Tailscale devices (run once on host) |
| `Makefile` | `make image`, `make launch`, `make ssh`, etc. — same ergonomics as the Docker `Makefile` |

## Prerequisites

- Bare-metal Ubuntu server (you confirmed yours is bare metal, so KVM works natively — no nested virt needed)
- Tailscale installed and running **on the server** (the VM will get its own Tailscale node, installed during first boot — see step 5)
- [MesloLGS NF](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k) font + a terminal that uses it, same as the Docker setup

## First-Time Setup

### 1. Install KVM, libvirt, and Packer (on the server)

```bash
cd vm
make install
```

Log out and back in for the `libvirt`/`kvm` group changes to take effect, then verify:

```bash
kvm-ok        # confirms hardware virtualization is usable
virsh list --all
```

### 2. Build the VM image

This is the VM analog of `docker compose build` — it boots an installer in headless
QEMU, runs the unattended Ubuntu install, then runs `provision.sh` to install the
same packages and dotfiles as the Dockerfile.

```bash
make image
```

This takes 10-20 minutes. The resulting qcow2 image lands in `packer/output/claude-sandbox/`.

> **Before running this**, open `packer/http/user-data` and replace the placeholder
> password hash with your own (`mkpasswd --method=sha-512`), or better, add your SSH
> public key under a `ssh-authorized-keys:` block and set `allow-pw: false`.

### 3. Create the isolated network

```bash
make network
```

This defines a dedicated libvirt NAT network (`sandbox-net`, `192.168.100.0/24`,
bridge `virbr-sandbox`) and applies iptables rules blocking that subnet from
reaching your LAN and Tailscale ranges — functionally the same isolation the
Docker `iptables.sh` applied to the container's bridge.

If your LAN subnet isn't `192.168.1.0/24`, edit `network-isolation.sh` first.

### 4. Launch the VM

```bash
make launch
```

This copies the built image to `/var/lib/libvirt/images/`, defines the VM with
`virt-install`, and starts it with 2 vCPUs / 4GB RAM (matching the container's
resource limits).

### 5. Install Tailscale inside the VM

Find the VM's DHCP address first:

```bash
make status
```

SSH in directly over the isolated network (you're still on the same host, so this
works even though the VM can't reach your LAN):

```bash
ssh sandbox@192.168.100.x
sudo curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh
```

From here on, reach the VM the same way you reached the container — via its
Tailscale IP/hostname — and the `network-isolation.sh` rules keep it from seeing
your LAN or other Tailscale devices directly.

### 6. Log in to Claude Code

```bash
ssh sandbox@<vm-tailscale-ip>
tmux attach -t main   # auto-created on login
claude
```

Follow the browser login flow as before. Unlike the container's bind-mounted
`./claude-auth`, credentials here live inside the VM's disk — they survive
reboots but not a `make destroy` + fresh `make launch` with a new disk.

## Daily Use

```bash
ssh sandbox@<vm-tailscale-ip>
# tmux session "main" auto-attaches on login
```

## Makefile Targets

| Target | Description |
|---|---|
| `make install` | Install KVM/libvirt/Packer on the server |
| `make image` | Build the VM image with Packer |
| `make network` | Create the isolated libvirt network + iptables rules |
| `make launch` | Define and start the VM from the built image |
| `make start` / `make stop` | Start/stop an existing VM |
| `make destroy` | Undefine the VM (disk image preserved on host) |
| `make status` | Show VM state and IP address |

## Network Isolation

| | Server (host) | VM |
|---|---|---|
| Internet | Yes | Yes (via NAT) |
| LAN (`192.168.x.x`, `10.x.x.x`, `172.16.x.x`) | Yes | No — blocked by `network-isolation.sh` |
| Tailscale devices (`100.64.0.0/10`) | Yes | No — blocked by `network-isolation.sh` |

Verify from inside the VM, same checks as the Docker setup:

```bash
ping -c 3 192.168.1.1     # should fail
ping -c 3 100.x.x.x       # should fail
ping -c 3 google.com      # should succeed
```

## Rebuilding

```bash
make destroy
rm /var/lib/libvirt/images/claude-sandbox.qcow2   # only if you want a clean disk
make image      # only needed if you changed provision.sh / packages
make launch
```

## Differences from the Docker setup

- **Isolation boundary**: hardware-virtualized VM vs. container namespaces — meaningfully stronger against kernel-level escapes.
- **No bind mounts**: workspace and Claude auth live on the VM's own disk, not host-mounted directories. Use `scp`/`rsync`, or add a `virtiofs`/9p share if you want host-shared folders.
- **Resource limits**: set at VM definition time (`--memory`/`--vcpus` in `virt-install`) instead of `docker-compose.yml`'s `deploy.resources.limits`.
- **Rebuild cost**: rebuilding the image (`make image`) is slower than `docker compose build` since it boots a real installer each time.
