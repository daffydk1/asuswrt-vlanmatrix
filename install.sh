#!/bin/sh
# VLAN Matrix installer for Asuswrt-Merlin
#
#   curl -fsSL https://raw.githubusercontent.com/daffydk1/asuswrt-vlanmatrix/main/install.sh | sh -s install
#
#   sh install.sh install      install, or update to the files next to this script / on GitHub (keeps your setup)
#   sh install.sh update       download the newest version from GitHub and install it
#   sh install.sh uninstall    remove VLAN Matrix and give the ports back to ASUS
#   sh install.sh remove-old   delete leftovers of the pre-release VLAN Matrix (/jffs/addons/vlan-matrix)
PATH=/sbin:/bin:/usr/sbin:/usr/bin; export PATH
REPO=${VM_REPO:-daffydk1/asuswrt-vlanmatrix}
BRANCH=${VM_BRANCH:-main}
ROOT=/jffs/addons/vlanmatrix
OLD=/jffs/addons/vlan-matrix
FILES="vm.sh vlanmatrix.asp install.sh"
fail(){ echo "ERROR: $*"; exit 1; }
case "$0" in */*) SRC=$(cd "$(dirname "$0")" && pwd);; *) SRC=$(pwd);; esac

download(){ # -> files in /tmp/vlanmatrix-dl, SRC points there
  url=https://raw.githubusercontent.com/$REPO/$BRANCH
  dl=/tmp/vlanmatrix-dl; rm -rf "$dl"; mkdir -p "$dl"
  echo "Downloading VLAN Matrix from github.com/$REPO ($BRANCH)"
  for f in $FILES; do
    curl -fsSL --retry 2 "$url/$f" -o "$dl/$f" 2>/dev/null || wget -q -O "$dl/$f" "$url/$f" || fail "could not download $f"
    [ -s "$dl/$f" ] || fail "downloaded $f is empty"
  done
  grep -q '^VERSION=' "$dl/vm.sh" && grep -q VLANMATRIX_V5_PAGE "$dl/vlanmatrix.asp" || fail "download looks wrong"
  SRC=$dl
}

hook(){ # file command -> idempotent block in a /jffs/scripts file
  f=/jffs/scripts/$1
  [ -f "$f" ] || printf '#!/bin/sh\n' > "$f"
  sed -i '/# vlanmatrix BEGIN/,/# vlanmatrix END/d' "$f"
  blk="# vlanmatrix BEGIN
$2
# vlanmatrix END"
  if [ "$(grep -v '^[[:space:]]*$' "$f" | tail -n1)" = "exit 0" ]; then
    last=$(grep -n '^exit 0$' "$f" | tail -n1 | cut -d: -f1)   # insert before a final 'exit 0'
    head -n $((last-1)) "$f" > "$f.tmp"; printf '%s\n' "$blk" >> "$f.tmp"; tail -n +"$last" "$f" >> "$f.tmp"; mv "$f.tmp" "$f"
  else
    printf '%s\n' "$blk" >> "$f"
  fi
  chmod 755 "$f"
}
unhook(){ f=/jffs/scripts/$1; [ -f "$f" ] && sed -i '/# vlanmatrix BEGIN/,/# vlanmatrix END/d' "$f"; }

disable_old(){ # pre-release VLAN Matrix (v1-v4): stop its hooks, cron job and menu tab
  f=/jffs/scripts/services-start
  if [ -f "$f" ] && grep -q 'VLAN_MATRIX_V4_START' "$f"; then
    sed -i '/# VLAN_MATRIX_V4_START/,/# VLAN_MATRIX_SAVED_BOOT_OBSERVER_V1_END/d' "$f"
    echo "old services-start block removed"
  fi
  [ -f "$f" ] && sed -i '/vlan-matrix\/vlan_matrix_/d' "$f"
  f=/jffs/scripts/service-event
  if [ -f "$f" ] && grep -q 'VLANMatrix event hook BEGIN' "$f"; then
    sed -i '/# VLANMatrix event hook BEGIN/,/# VLANMatrix event hook END/d' "$f"; echo "old service-event hook removed"
  fi
  cru d VLANMatrixWebUI 2>/dev/null
  for p in /www/user/user*.asp; do
    [ -L "$p" ] && case "$(readlink "$p")" in "$OLD"/*) rm -f "$p"; echo "old web page $p removed";; esac
  done
}

install(){
  [ -f /usr/sbin/helper.sh ] || fail "this is not Asuswrt-Merlin"
  [ -d /jffs/scripts ] || fail "/jffs is not available - enable JFFS in Administration > System"
  fw="$(nvram get firmver 2>/dev/null | tr -d .).$(nvram get buildno)_$(nvram get extendno)"
  case "$fw" in 3006.102.9_*) ;; *) echo "Note: VLAN Matrix is tested on Merlin 3006.102.9 - this router runs $fw. It will most likely work; please report problems.";; esac
  [ "$(nvram get sw_mode)" = 1 ] || echo "Note: the router is not in router mode - VLAN Matrix is tested in router mode only."
  for f in vm.sh vlanmatrix.asp; do [ -f "$SRC/$f" ] || { download; break; }; done
  case "$(nvram get productid)" in RT-BE88U) ;; *)
    [ -f "$ROOT/ports.map" ] || [ -f "$SRC/ports.map" ] || fail "$(nvram get productid) has no port map yet - see README (Other models)";;
  esac
  [ "$(nvram get jffs2_scripts)" = 1 ] || { nvram set jffs2_scripts=1; nvram commit; echo "enabled JFFS custom scripts"; }
  old=$(sed -n 's/^VERSION=//p' "$ROOT/vm.sh" 2>/dev/null)
  mkdir -p "$ROOT"
  for f in $FILES ports.map; do
    [ -f "$SRC/$f" ] && [ "$SRC/$f" != "$ROOT/$f" ] && tr -d '\r' < "$SRC/$f" > "$ROOT/$f.new" && mv "$ROOT/$f.new" "$ROOT/$f"
  done
  chmod 755 "$ROOT/vm.sh" "$ROOT/install.sh"
  rm -f "$ROOT/created.list"   # leftover from 5.0.0
  new=$(sed -n 's/^VERSION=//p' "$ROOT/vm.sh")
  disable_old
  hook services-start    "/bin/sh $ROOT/vm.sh boot"
  hook service-event     "/bin/sh $ROOT/vm.sh event \"\$1\" \"\$2\""
  hook service-event-end "/bin/sh $ROOT/vm.sh event-end \"\$1\" \"\$2\""
  /bin/sh "$ROOT/vm.sh" webui
  /bin/sh "$ROOT/vm.sh" apply
  cru a vlanmatrix_heal "*/5 * * * * /bin/sh $ROOT/vm.sh apply"
  rm -rf /tmp/vlanmatrix-dl
  page=$(grep -l VLANMATRIX_V5_PAGE /www/user/user*.asp 2>/dev/null | head -n1)
  echo
  if [ -n "$old" ]; then echo "VLAN Matrix updated: $old -> $new"; else echo "VLAN Matrix $new installed."; fi
  echo "Open the router page: LAN > VLAN > VLAN Matrix (${page##*/}). Press Ctrl+F5 if the tab is missing."
  [ -f "$ROOT/asus-ports.backup" ] || echo "Tip: run '$ROOT/vm.sh takeover' so ports are configured in one place only."
  [ -d "$OLD" ] && echo "Leftovers of an older VLAN Matrix found. Delete them with: sh $ROOT/install.sh remove-old"
  return 0
}

uninstall(){
  [ -f "$ROOT/vm.sh" ] || { echo "VLAN Matrix is not installed"; return 0; }
  /bin/sh "$ROOT/vm.sh" rollback >/dev/null 2>&1
  # Give the ports back to ASUS (restores the ASUS port settings from before 'takeover')
  [ -f "$ROOT/asus-ports.backup" ] && /bin/sh "$ROOT/vm.sh" giveback
  unhook services-start; unhook service-event; unhook service-event-end
  cru d vlanmatrix_heal 2>/dev/null; cru d vlanmatrix_wd 2>/dev/null
  for p in /www/user/user*.asp; do [ -f "$p" ] && grep -q VLANMATRIX_V5_PAGE "$p" && rm -f "$p"; done
  if [ -f /tmp/menuTree.js ]; then
    sed -i '/tabName: "VLAN Matrix"/d' /tmp/menuTree.js
    sed -i 's#^//\({url: "Advanced_VLAN_Switch_Content.asp"\)#\1#' /tmp/menuTree.js
    umount /www/require/modules/menuTree.js 2>/dev/null; mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
  fi
  [ -f "$ROOT/ports.conf" ] && cp "$ROOT/ports.conf" /jffs/addons/vlanmatrix-ports.conf.saved && echo "Your setup was saved to /jffs/addons/vlanmatrix-ports.conf.saved"
  rm -rf "$ROOT" /www/user/vlanmatrix /tmp/vlanmatrix /tmp/vlanmatrix.lock
  echo "VLAN Matrix removed. Ports follow the ASUS VLAN page again after the network restart."
}

remove_old(){
  disable_old
  rm -rf "$OLD" /www/user/vlan-matrix-api /tmp/vlan-matrix-* /tmp/vlan_matrix_* 2>/dev/null
  echo "Old VLAN Matrix leftovers removed."
}

case "${1:-}" in
  install)    install;;
  update)     download; install;;
  uninstall)  uninstall;;
  remove-old) remove_old;;
  *) echo "Usage: sh install.sh install|update|uninstall|remove-old"; exit 1;;
esac
