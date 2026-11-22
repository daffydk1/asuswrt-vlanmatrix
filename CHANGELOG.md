# Changelog

## 5.4.0
- **AiMesh wired backhaul protection.** If an AiMesh node is seen behind a LAN port, that port is locked at the ASUS
  default (Main untagged, all VLANs tagged) – like the WAN port it is never changed and shown as "AiMesh" in the GUI.
  The lock is remembered (also while the node is off); `vm.sh protect ethX` / `vm.sh unprotect ethX` set or clear it by hand.
- *Takeover* now resets only this router's own ASUS port settings. AiMesh nodes keep theirs.

## 5.3.1
- After creating or deleting a network, a waiting screen counts up and the page reloads only when the router answers
  again (no "connection refused" page). You may have to log in again.

## 5.3.0
- Create and delete VLAN networks (VLAN profiles) from VLAN Matrix. It drives the ASUS VLAN Profiles page in the
  background, so the data (SDN profile, VLAN, subnet + DHCP) is written exactly as ASUS does. Wi-Fi names stay on the ASUS page.

## 5.2.3
- VLAN Matrix is now the last tab: VLAN · VLAN Profiles · VLAN Matrix.

## 5.2.2
- The ASUS *VLAN* port tab is no longer hidden after `takeover`; tabs are now VLAN · VLAN Matrix · VLAN Profiles.

## 5.2.1
- Fix: VLAN Matrix could take the web page slot of another addon (e.g. Skynet), so that addon's tab opened
  the wrong page and the router GUI hung. It now never uses a userN.asp slot another tab points to,
  and moves away from one if it already sits there.
- Installer says "reinstalled" when the version is unchanged.

## 5.2.0 – first public release
Tested on Asuswrt-Merlin 3006.102.9, RT-BE88U, router mode.

- Rear-panel web page: ports with untagged light and tagged bars, per-port editor, devices per port.
- Test with automatic revert after 5 minutes; Keep saves the setup.
- Setup re-applied at boot, after ASUS network restarts and every 5 minutes.
- `takeover` / `giveback`: replace the ASUS port page and give it back.
- Port link is bounced (`ethctl phy-power`) when the untagged network changes, so devices renew their IP.
- All active IP addresses per device; names borrowed from sibling NICs.
- WAN port detected and never managed.
- Installer: `curl … | sh -s install`, `update`, `uninstall` (restores the ASUS port settings), `remove-old`.
- Log messages that would repeat every 5 minutes are written once per boot.
