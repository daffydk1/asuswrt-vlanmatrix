# Changelog

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
