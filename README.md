# I2P-node

A small bootstrap installer for running a Java I2P router on a Debian VPS, with an optional-ready local website origin for an I2P Eepsite.

## Supported system

- Debian 12 (Bookworm)
- Debian 13 (Trixie)
- systemd
- Root or sudo access

Other distributions are intentionally rejected for now.

## Install

Connect to your VPS over SSH, then run:

```bash
sudo apt-get update
sudo apt-get install -y git
git clone https://github.com/AL3XZIG/I2P-node.git
cd I2P-node
sudo bash install.sh
```

The installer asks for confirmation, then:

1. Installs prerequisite packages.
2. Downloads the official I2P APT signing key and checks its full fingerprint.
3. Adds the official `deb.i2p.net` repository.
4. Installs Java I2P and `i2p-keyring`.
5. Enables and starts `i2p.service` when the package provides that unit.
6. Installs Nginx and prepares a sample website at `/var/www/i2p-site`.
7. Binds the website origin only to `127.0.0.1:8080`.

The installer does **not** change firewall rules, expose the Router Console, or force the router to become Floodfill.

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

## Uninstall notes

The installer does not provide an automatic destructive uninstall. To remove components, review the services and files first; do not delete I2P router identity/key material unless you intentionally want to discard that router identity.

## Official references

- [I2P installation guide for Debian/Ubuntu](https://i2p.net/en/docs/guides/installing-i2p-on-debian-and-ubuntu/)
- [I2P transport overview](https://i2p.net/en/docs/overview/transport/)
- [I2P Router Console configuration](https://i2p.net/en/docs/guides/router-console-config/)
