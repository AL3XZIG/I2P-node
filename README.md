# I2P-node

A bootstrap installer for running a Java I2P router on Debian or Ubuntu VPS instances, with a local Nginx website origin for an I2P Eepsite.

## Supported systems

- Debian 12 (Bookworm)
- Debian 13 (Trixie)
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)
- Ubuntu 26.04 LTS (Resolute)
- systemd
- Root or sudo access

Other distributions and releases are intentionally rejected.

## Important: intended server environment

**Use this installer on a fresh VPS or a server dedicated to I2P-node. Do not run it blindly on a shared, existing production server.**

The installer changes system-level configuration and installs/enables services. In particular, it:

- Adds or changes APT repository configuration (Debian repository or Ubuntu I2P PPA).
- Installs Java I2P, Nginx, and prerequisite packages.
- Enables and starts the I2P and Nginx systemd services.
- Creates or replaces the Nginx vhost at `/etc/nginx/sites-available/i2p-site`.
- Enables the I2P site and, after a separate confirmation, disables `/etc/nginx/sites-enabled/default`.
- Does not modify firewall rules or expose the I2P Router Console.

Before making these changes, it stores copies of existing APT source-list configuration, the I2P repository keyring if present, and the existing `/etc/nginx` tree in a timestamped directory under:

```
/root/i2p-node-backups/
```

Backups are created with root-only permissions. The installer **does not provide an automatic rollback**. If installation fails or you need to restore a previous configuration, inspect the backup and restore the relevant files manually. Do not blindly overwrite the entire configuration tree on a running server.

## Install

Connect to your VPS over SSH, then run:

```bash
sudo apt-get update
sudo apt-get install -y git
git clone https://github.com/AL3XZIG/I2P-node.git
cd I2P-node
sudo bash install.sh
```

The installer asks for confirmation before making changes. It detects Debian or Ubuntu and selects the corresponding I2P package source:

1. Debian: downloads the official I2P APT signing key, verifies its full fingerprint, and adds `deb.i2p.net`.
2. Ubuntu: adds the official `ppa:i2p-maintainers/i2p` PPA.
3. Installs Java I2P (and `i2p-keyring` on Debian).
4. Enables and starts the I2P system service, then verifies that it is active. Installation stops if the service is missing or fails to start.
5. Installs Nginx and prepares a sample website at `/var/www/i2p-site`.
6. Binds the website origin only to `127.0.0.1:8080`.

When the Nginx default site is enabled, the installer prints a warning, identifies the backup location, and asks for separate confirmation before disabling it.

## After installation

### Check I2P

```bash
sudo systemctl status i2p
sudo journalctl -u i2p -f
```

Router Console listens locally at `127.0.0.1:7657`. To access it from your own computer, create an SSH tunnel:

```bash
ssh -L 7657:127.0.0.1:7657 USER@SERVER_IP
```

Then open `http://127.0.0.1:7657` on your own computer.

### Publish the sample website as an Eepsite

The local Nginx origin is:

```
http://127.0.0.1:8080/
```

In the I2P Router Console:

1. Open **Hidden Services Manager**.
2. Create an **HTTP Server Tunnel**.
3. Set the target host to `127.0.0.1` and target port to `8080`.
4. Start the tunnel and copy its generated `.i2p` destination/address.
5. Publish the address through an I2P address book if you want other users to find it easily.

The installer prepares the web server but does not create or publish the I2P tunnel automatically.

Replace the sample page in `/var/www/i2p-site` with your own website files. Keep the Nginx origin bound to localhost; the I2P server tunnel is the public entry point.

## Network ports and firewall

I2P uses NTCP2 over TCP and SSU2 over UDP. The router console port `7657/TCP` must remain private.

After the router starts, find its configured transport port in **Router Console → Network Configuration**. Allow that TCP and UDP port in both the VPS provider firewall and the host firewall, if enabled. Do not blindly open the console, proxy, or unrelated ports.

## Floodfill

Floodfill is a role assigned automatically by the I2P network based on router conditions and network needs. This installer does not and cannot guarantee or force Floodfill status. Keep the router online, reachable, updated, and adequately provisioned, then verify its status in the Router Console.

## Uninstall and recovery notes

There is no automatic uninstall or rollback. Review the services and files before removing components. Do not delete I2P router identity/key material unless you intentionally want to discard that router identity. Configuration backups are stored in `/root/i2p-node-backups/`.

## Checks

The repository includes GitHub Actions checks for Bash syntax and ShellCheck:

```bash
bash -n install.sh
shellcheck install.sh
```

## Official references

- [I2P installation guide for Debian/Ubuntu](https://i2p.net/en/docs/guides/installing-i2p-on-debian-and-ubuntu/)
- [I2P transport overview](https://i2p.net/en/docs/overview/transport/)
- [I2P Router Console configuration](https://i2p.net/en/docs/guides/router-console-config/)
