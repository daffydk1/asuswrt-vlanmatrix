# VLAN Matrix for Asuswrt-Merlin

Choose **Untagged / Tagged / Off** for every VLAN on every LAN port of your ASUS router – and create or delete the
VLAN networks themselves – on one page.
The stock ASUS VLAN page only offers *Default*, *Access* (one VLAN) or *Trunk* (all VLANs) per port.

> **Built and tested on Asuswrt-Merlin 3006.102.9 on an RT-BE88U in router mode.**
> Other Merlin versions and models may work but are untested – see [Other models](#other-models) and please report back.

<p align="center"><img src="docs/screenshot.png" width="620" alt="VLAN Matrix: rear panel, port editor and networks"></p>

## Features

- **Rear-panel view** – every port with its untagged network (light) and tagged networks (bars). Click a port to edit it.
- **Untagged / Tagged / Off per network per port** – one untagged network per port, any number of tagged ones.
- **Networks** – create and delete VLAN networks (VLAN profiles) right here; subnet and DHCP are set up as ASUS does.
- **Test first** – changes are applied at once and **revert automatically after 5 minutes** unless you press *Keep*.
  You cannot lock yourself out.
- **Persistent** – the saved setup is re-applied at boot, after every ASUS network restart and every 5 minutes.
- **Devices per port** – name, IP address(es), network and MAC of what is plugged in.
- **New IP straight away** – when a port's untagged network changes, the port is switched off for 3 seconds so the
  device asks for a new address (no need to unplug the cable).
- **Plays nicely** – the WAN port and AiMesh wired backhaul ports are detected and never touched; other addons' pages (e.g. Skynet) are left alone.
- **Small** – one shell script and one web page. No Entware.

Tabs on the router: **LAN → VLAN · VLAN Profiles · VLAN Matrix**.

## Requirements

- Asuswrt-Merlin **3006.102.9** (tested) – other 3006.102.x builds will most likely work
- Router mode (not AP / mesh node)
- *Administration → System → Enable JFFS custom scripts and configs*, and SSH access

## Install

Log in to the router with SSH and run:

```sh
curl -fsSL https://raw.githubusercontent.com/daffydk1/asuswrt-vlanmatrix/main/install.sh | sh -s install
```

Open **LAN → VLAN → VLAN Matrix** (press Ctrl+F5 once if the tab is missing).

**Recommended:** let VLAN Matrix take over the port settings, so ports are configured in one place only:

```sh
/jffs/addons/vlanmatrix/vm.sh takeover
```

Your current ASUS port setup (trunk / access ports) is copied into VLAN Matrix, every port is set to *Default* in ASUS
and the network restarts once (~30 s). `vm.sh giveback` restores the ASUS port settings.

| Task | Command |
|---|---|
| Update | `sh /jffs/addons/vlanmatrix/install.sh update` |
| Uninstall | `sh /jffs/addons/vlanmatrix/install.sh uninstall` – gives the ports back to ASUS and keeps a copy of your setup in `/jffs/addons/vlanmatrix-ports.conf.saved` |

## Use

### Ports
1. Click a port on the rear panel.
2. Tick **Manage** – the port's current state is copied in.
3. Choose **Untagged / Tagged / Off** per network. Choosing Untagged switches the port's previous untagged network off.
4. **Test for 5 min**, check that everything works, then **Keep** – or do nothing and it reverts by itself.
   Changes on several ports can be tested together; ports with untested changes get a yellow dot.

| Manage | Meaning |
|---|---|
| ticked | VLAN Matrix keeps the port exactly as set – at boot, after ASUS network restarts and every 5 minutes. |
| not ticked | VLAN Matrix does not touch the port; it follows ASUS (after *takeover*: Main untagged, all VLANs tagged). |

A port you stop managing keeps its state until the next reboot or network restart. A new VLAN is *Tagged* on all ports
(the ASUS default) until you set it. Managed ports win over changes made on the ASUS *VLAN* tab.

### Untagged or tagged?
- A normal device – PC, phone, printer, TV – needs its network as **Untagged**.
- **Tagged** is for VLAN-aware equipment: managed switches, access points with several SSIDs, NAS/Proxmox/Docker hosts
  with VLAN interfaces.

### Networks
In the **Networks** card you can add a network (VLAN ID 3–4093, optionally *isolate devices from each other*) or delete
one. VLAN Matrix drives the ASUS *VLAN Profiles* page in the background, so the SDN profile, VLAN, subnet and DHCP are
written exactly as ASUS does (192.168.&lt;VLAN ID&gt;.1/24 for IDs up to 254). The router restarts its network and Wi-Fi
(about a minute); a waiting screen reloads the page when the router answers again – you may have to log in again.
Wi-Fi names (SSIDs) for a network are set on the ASUS *VLAN Profiles* tab.

### Avoid loops
ASUS VLAN bridges have no spanning tree. If one device or switch is connected to **two router ports**, give each network
to **only one** of them. Example: a NAS with two NICs on *10G* and *LAN2* – Main, 52 and 53 on 10G, VLAN 20 and 30 on
LAN2 – never the same VLAN on both. Otherwise a bridge or Docker network on the device creates a loop and the whole
network (LAN and Wi-Fi) drops out now and then.

## Command line

```sh
vm=/jffs/addons/vlanmatrix/vm.sh
$vm status                         # current state as JSON
$vm test "eth3:main=U,20=T,30=O"   # try a setup (reverts after 5 min)
$vm confirm                        # keep it
$vm rollback                       # undo now
$vm takeover | giveback            # take over the ASUS port settings / give them back
$vm protect | unprotect eth5       # lock a port by hand (e.g. AiMesh backhaul) / unlock it
```

Saved setup: `/jffs/addons/vlanmatrix/ports.conf`, one line per managed port, e.g. `eth3 main=U 20=T 30=O`.
Log: `/jffs/addons/vlanmatrix/vlanmatrix.log`.

## How it works

ASUS creates one Linux bridge per VLAN (e.g. VLAN 20 → `br55`) and VLAN sub-interfaces (`eth3.20`) in it.

| Choice   | What VLAN Matrix does                                        |
|----------|--------------------------------------------------------------|
| Untagged | the port itself (`eth3`) becomes a member of the VLAN bridge |
| Tagged   | `eth3.20` is created if needed and joined to the bridge      |
| Off      | neither is a member                                          |

Only `brctl`, `vconfig`/`ip`, `ethctl` and `fcctl` are used. Bridges are discovered from the interfaces ASUS creates, so
no VLAN IDs, bridge names or MAC addresses are hard-coded. NVRAM is only written by *takeover*/*giveback* and when you
create or delete a network (through the ASUS page).

Notes for Broadcom routers:
- VLAN sub-interfaces are never deleted, only detached – a deleted one often cannot be re-created until reboot.
- `ip link set down` does not switch the physical port off; `ethctl <if> phy-power down/up` does.
- The hardware flow cache is flushed (`fcctl flush`) after changes.

## Other models

Ports are mapped per model in `vm.sh` (`port_map`). For another model create `/jffs/addons/vlanmatrix/ports.map`, one
line per port – label, interface and optionally `sfp`:

```
LAN1 eth1
LAN2 eth2
SFP+ eth9 sfp
```

A port in use as WAN is detected and never managed. Find your interfaces with `brctl show` and by plugging a cable in
(`cat /sys/class/net/eth*/carrier`). Please open an issue or pull request with a working map for your model.

RT-BE88U map (names as on the ASUS VLAN page): LAN1 (2.5G WAN/LAN) = eth1, LAN2–LAN4 (2.5G) = eth2–eth4,
LAN5–LAN8 (1G) = eth5–eth8, 10G SFP+ = eth9, 10G WAN/LAN = eth0.

## Safety

Use at your own risk. While testing, keep a second way into the router (Wi-Fi or another port) – the 5-minute
auto-revert is there for exactly that. A test never survives a reboot.

## Changelog and license

See [CHANGELOG.md](CHANGELOG.md). MIT – see [LICENSE](LICENSE).
