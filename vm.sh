#!/bin/sh
# VLAN Matrix v5 - Tagged / Untagged / Off per VLAN on each LAN port.
# Asuswrt-Merlin addon. See README.md
#
#   vm.sh apply              apply the saved setup (ports.conf), or the test setup while a test runs
#   vm.sh test  <cfg>        try a setup; reverts automatically after TEST_SECONDS
#   vm.sh confirm            keep the test setup (saved to ports.conf)
#   vm.sh rollback           undo the test setup now
#   vm.sh status             write status.json for the web page and print it
#   vm.sh takeover|giveback  let VLAN Matrix replace the ASUS port page / give it back
#   vm.sh boot               called from services-start
#   vm.sh event[-end] A B    called from service-event / service-event-end
#
# <cfg> format:  "eth3:main=U,20=T,30=O;eth5:main=O,60=U"   (U=untagged, T=tagged, O=off)
# Ports not in the setup are never touched (ASUS decides).

VERSION=5.3.1
PATH=/sbin:/bin:/usr/sbin:/usr/bin; export PATH
ROOT=/jffs/addons/vlanmatrix
CONF=$ROOT/ports.conf
STATE=/tmp/vlanmatrix
TESTCONF=$ROOT/ports.conf.test
SNAP=$ROOT/test.snapshot
DEADLINE=$ROOT/test.deadline
API=/www/user/vlanmatrix
LOG=$ROOT/vlanmatrix.log
LOCK=/tmp/vlanmatrix.lock
TEST_SECONDS=300
umask 022

log(){ echo "$(date '+%F %T') $*" >> "$LOG"; logger -t vlanmatrix "$*" 2>/dev/null; }
logonce(){ # same message only once per boot (the 5-minute self-heal must not fill the flash)
  grep -qxF "$*" "$STATE/logged" 2>/dev/null && return 0
  echo "$*" >> "$STATE/logged"; log "$*"
}
trimlog(){ [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 200000 ] && tail -n 500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"; }
say(){ echo "$*"; log "$*"; }
die(){ say "ERROR: $*"; exit 1; }

# ---------- ports per model ----------
port_map(){
  # Output: "LABEL IFACE [sfp]" per line. ports.map overrides the built-in map.
  if [ -f "$ROOT/ports.map" ]; then grep -E '^[A-Za-z0-9+/-]+ eth[0-9]+( sfp)?$' "$ROOT/ports.map"; return; fi
  case "$(nvram get productid)" in
    # Names as on the ASUS VLAN page. A port used as WAN is never managed (see wan_ifaces).
    RT-BE88U) printf 'LAN1 eth1\nLAN2 eth2\nLAN3 eth3\nLAN4 eth4\nLAN5 eth5\nLAN6 eth6\nLAN7 eth7\nLAN8 eth8\nSFP+ eth9 sfp\n10G eth0\n';;
    *) return 1;;
  esac
}
wan_ifaces(){ for k in wan_ifnames wan_ifname wan0_ifname wan1_ifname wans_dualwan_ifnames; do nvram get $k 2>/dev/null; done | tr ' ' '\n' | grep -E '^eth[0-9]+$' | sort -u; }
is_wan(){ wan_ifaces | grep -qx "$1"; }
managed_ifaces(){ port_map | awk -v w=" $(wan_ifaces | tr '\n' ' ') " 'index(w, " "$2" ")==0{print $2}'; }
is_managed(){ managed_ifaces | grep -qx "$1"; }

# ---------- lock ----------
lock(){
  n=0
  while ! mkdir "$LOCK" 2>/dev/null; do
    pid=$(cat "$LOCK/pid" 2>/dev/null)
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then rm -rf "$LOCK"; continue; fi
    n=$((n+1)); [ $n -gt 30 ] && die "busy (another run holds the lock)"
    sleep 1
  done
  echo $$ > "$LOCK/pid"
  trap 'rm -rf "$LOCK"' EXIT
  trap 'exit 1' INT TERM HUP
}

# ---------- read Linux state ----------
master(){ m=$(readlink "/sys/class/net/$1/master" 2>/dev/null); echo "${m##*/}"; }
exists(){ [ -e "/sys/class/net/$1" ]; }

# VID -> bridge, found from the VLAN interfaces ASUS creates (e.g. eth0.20 in br55).
discover(){
  mkdir -p "$STATE"
  : > "$STATE/vidmap.new"
  awk -F'|' 'NR>2{gsub(/ /,"");print $1, $2, $3}' /proc/net/vlan/config 2>/dev/null |
  while read dev vid parent; do
    case "$parent" in eth*) ;; *) continue;; esac
    br=$(master "$dev")
    case "$br" in br[0-9]*) [ "$br" != br0 ] && echo "$vid $br";; esac
  done | awk '!s[$1]++' > "$STATE/vidmap.new"
  # Remember known VLANs even if every port is removed from them (live wins over cache).
  # A cache entry is used only if neither its VID nor its bridge is in use live (ASUS reuses bridges).
  { cat "$STATE/vidmap.new"; [ -f "$ROOT/vidmap.cache" ] && cat "$ROOT/vidmap.cache"; } |
    awk '!v[$1]++ && !b[$2]++' | sort -n > "$STATE/vidmap"
  # Keep only VLANs whose bridge still exists
  while read vid br; do [ -d "/sys/class/net/$br/bridge" ] && echo "$vid $br"; done < "$STATE/vidmap" > "$STATE/vidmap.ok"
  mv "$STATE/vidmap.ok" "$STATE/vidmap"
  # Write to /jffs only on change (spares the flash)
  if [ -s "$STATE/vidmap.new" ] && ! cmp -s "$STATE/vidmap" "$ROOT/vidmap.cache"; then cp "$STATE/vidmap" "$ROOT/vidmap.cache"; fi
  rm -f "$STATE/vidmap.new"
}
bridge_of(){ awk -v v="$1" '$1==v{print $2}' "$STATE/vidmap"; }
vids(){ awk '{print $1}' "$STATE/vidmap"; }

# ---------- changes ----------
bounce(){ # Simulate unplug/replug so the device on the port asks for a new IP address
  if ethctl "$1" phy-power down >/dev/null 2>&1; then
    sleep 3; ethctl "$1" phy-power up >/dev/null 2>&1; how=phy
  else
    ip link set "$1" down; sleep 3; ip link set "$1" up; how=ip
  fi
  ip link set "$1" up 2>/dev/null
  log "  $1: link bounced ($how) so the device renews its IP"
}
setmaster(){ # iface bridge|- : move an interface into a bridge (or out of all)
  ifc=$1; want=$2; cur=$(master "$ifc")
  [ "$cur" = "$want" ] && return 0
  [ "$want" = - ] && [ -z "$cur" ] && return 0
  if [ -n "$cur" ]; then brctl delif "$cur" "$ifc" && log "  $ifc: out of $cur"; fi
  if [ "$want" != - ]; then
    ip link set "$ifc" up 2>/dev/null
    brctl addif "$want" "$ifc" && log "  $ifc: into $want"
  fi
}
ensure_sub(){ # port vid  (VLAN interfaces are NEVER deleted: Broadcom kernels cannot re-create the name)
  exists "$1.$2" && return 0
  e1=$(vconfig add "$1" "$2" 2>&1) || e2=$(ip link add link "$1" name "$1.$2" type vlan id "$2" 2>&1)
  exists "$1.$2" || { logonce "could not create $1.$2: $e1 $e2"; return 1; }
  log "  created $1.$2"
}

# Apply one port: "eth3 main=U 20=T 30=O"
apply_line(){
  set -- $1
  p=$1; shift
  is_managed "$p" || { logonce "skip $p (not a managed port)"; return; }
  exists "$p" || { logonce "skip $p (does not exist)"; return; }
  # Which network is the port untagged in? Default: unchanged.
  cur=$(master "$p"); native=keep
  for kv in "$@"; do
    k=${kv%%=*}; v=${kv#*=}
    if [ "$k" = main ]; then b=br0; else b=$(bridge_of "$k"); fi
    [ -n "$b" ] || continue
    if [ "$v" = U ]; then native=$b
    elif [ "$native" = keep ] && [ "$cur" = "$b" ]; then native=-   # its current untagged network is switched off
    fi
  done
  if [ "$native" != keep ] && [ "$native" != "$(master "$p" | sed 's/^$/-/')" ]; then
    setmaster "$p" "$native"
    # Untagged network changed: bounce the link so the device renews its IP
    bounce "$p"
    touch "$STATE/flush"
  fi
  ip link set "$p" up 2>/dev/null
  for kv in "$@"; do
    k=${kv%%=*}; v=${kv#*=}
    [ "$k" = main ] && continue
    b=$(bridge_of "$k"); [ -n "$b" ] || { logonce "VLAN $k in the setup does not exist on the router (ignored)"; continue; }
    if [ "$v" = T ]; then
      ensure_sub "$p" "$k" && { ip link set "$p.$k" up; [ "$(master "$p.$k")" = "$b" ] || touch "$STATE/flush"; setmaster "$p.$k" "$b"; }
    else
      if exists "$p.$k" && [ -n "$(master "$p.$k")" ]; then setmaster "$p.$k" -; touch "$STATE/flush"; fi
    fi
  done
}

active_conf(){ if [ -f "$TESTCONF" ]; then echo "$TESTCONF"; else echo "$CONF"; fi; }

do_apply(){
  trimlog
  discover
  f=$(active_conf)
  [ -f "$f" ] || return 0
  rm -f "$STATE/flush"
  grep -E '^eth[0-9]+( [a-z0-9]+=[UTO])*$' "$f" | while read line; do apply_line "$line"; done
  flush_hw
}
flush_hw(){ # Broadcom hardware forwarding remembers old paths - flush it after changes
  [ -f "$STATE/flush" ] || return 0
  rm -f "$STATE/flush"
  fcctl flush >/dev/null 2>&1 && log "  flow cache flushed"
}

# ---------- test and undo ----------
snapshot(){
  : > "$SNAP"
  for p in $(managed_ifaces); do
    exists "$p" || continue
    echo "if $p $(master "$p" | sed 's/^$/-/')" >> "$SNAP"
    for s in /sys/class/net/$p.*; do
      [ -e "$s" ] || continue; s=${s##*/}
      echo "if $s $(master "$s" | sed 's/^$/-/')" >> "$SNAP"
    done
  done
}
restore_snapshot(){
  [ -f "$SNAP" ] || return 0
  # VLAN interfaces created during the test are detached (never deleted)
  for p in $(managed_ifaces); do
    for s in /sys/class/net/$p.*; do
      [ -e "$s" ] || continue; s=${s##*/}
      grep -q "^if $s " "$SNAP" || setmaster "$s" -
    done
  done
  while read t ifc br; do
    [ "$t" = if ] && exists "$ifc" || continue
    if [ "$(master "$ifc" | sed 's/^$/-/')" != "$br" ]; then
      setmaster "$ifc" "$br"; touch "$STATE/flush"
      case "$ifc" in *.*) ;; *) bounce "$ifc";; esac
    fi
  done < "$SNAP"
  flush_hw
}
end_test(){ rm -f "$TESTCONF" "$SNAP" "$DEADLINE"; cru d vlanmatrix_wd 2>/dev/null; }

parse_cfg(){ # "eth3:main=U,20=T;eth5:..." -> ports.conf lines on stdout. Strict check.
  echo "$1" | tr ';' '\n' | while IFS= read -r part; do
    [ -z "$part" ] && continue
    p=${part%%:*}; rest=${part#*:}
    echo "$p" | grep -qE '^eth[0-9]+$' || { echo "BAD"; return; }
    is_managed "$p" || { echo "BAD"; return; }
    line=$p; nu=0
    for kv in $(echo "$rest" | tr ',' ' '); do
      echo "$kv" | grep -qE '^(main|[0-9]{1,4})=[UTO]$' || { echo "BAD"; return; }
      [ "${kv#main=}" = T ] && { echo "BAD"; return; }
      [ "${kv#*=}" = U ] && nu=$((nu+1))
      line="$line $kv"
    done
    [ $nu -le 1 ] || { echo "BAD"; return; }
    echo "$line"
  done
}

cmd_test(){
  cfg=$1
  out=$(parse_cfg "$cfg")
  echo "$out" | grep -q BAD && die "invalid setup: $cfg"
  discover
  [ -f "$TESTCONF" ] || snapshot      # new test while one runs: keep the first snapshot
  printf '%s\n' "$out" | grep . > "$TESTCONF.tmp"; mv "$TESTCONF.tmp" "$TESTCONF"
  echo $(( $(date +%s) + TEST_SECONDS )) > "$DEADLINE"
  cru a vlanmatrix_wd "* * * * * /bin/sh $ROOT/vm.sh watchdog"
  say "Test started - reverts in $TEST_SECONDS s unless you press Keep"
  do_apply
}
cmd_confirm(){
  [ -f "$TESTCONF" ] || die "no test to keep"
  cp "$TESTCONF" "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
  end_test
  say "Saved - the setup is now also used after reboot"
}
cmd_rollback(){
  [ -f "$TESTCONF" ] || { say "No test running"; return 0; }
  discover
  restore_snapshot
  end_test
  do_apply   # re-apply the saved setup (if any)
  say "Test undone - previous setup restored"
}
cmd_watchdog(){
  [ -f "$DEADLINE" ] || { cru d vlanmatrix_wd 2>/dev/null; return; }
  [ "$(date +%s)" -ge "$(cat "$DEADLINE")" ] && { log "test time is up - reverting"; cmd_rollback; }
}

# ---------- live state and devices ----------
live_state(){ # port -> "main=U 20=T 30=O ..."
  m=$(master "$1"); out="main=$([ "$m" = br0 ] && echo U || echo O)"
  while read vid br; do
    if [ "$m" = "$br" ]; then st=U; elif [ "$(master "$1.$vid")" = "$br" ]; then st=T; else st=O; fi
    out="$out $vid=$st"
  done < "$STATE/vidmap"
  echo "$out"
}
collect_clients(){ # -> $STATE/clients: "port net ip mac name"
  : > "$STATE/clients"
  cat /var/lib/misc/dnsmasq*.leases 2>/dev/null | awk '{print tolower($2), $3, $4}' > "$STATE/leases"
  { echo "0 br0"; cat "$STATE/vidmap"; } | while read vid br; do
    [ -d "/sys/class/net/$br/brif" ] || continue
    net=$([ "$vid" = 0 ] && echo Main || echo "VLAN $vid")
    : > "$STATE/portno"
    for i in /sys/class/net/$br/brif/*; do echo "$(printf '%d' "$(cat "$i/port_no")") ${i##*/}" >> "$STATE/portno"; done
    brctl showmacs "$br" 2>/dev/null | awk 'NR>1 && $3=="no"{print $1, tolower($2)}' | while read pn mac; do
      ifc=$(awk -v n="$pn" '$1==n{print $2}' "$STATE/portno"); p=${ifc%%.*}
      is_managed "$p" || continue
          # All complete ARP entries (flag 0x2) - a device can have several, e.g. static IP + DHCP lease
      ip=$(awk -v m="$mac" -v b="$br" 'NR>1 && tolower($4)==m && $6==b && $3!="0x0"{print $1}' /proc/net/arp | sort -t. -k4,4n | tr '\n' ' ' | sed 's/ $//; s/ /, /g')
      [ -n "$ip" ] || ip=$(awk -v m="$mac" '$1==m{print $2; exit}' "$STATE/leases")
      name=$(awk -v m="$mac" '$1==m && $3!="*"{print $3; exit}' "$STATE/leases")
      # No name? Borrow it from a sibling NIC (same MAC except the last byte), e.g. a NAS with 2 ports
      if [ -z "$name" ]; then
        pre=${mac%:*}; name=$(awk -v p="$pre" 'index($1,p":")==1 && $3!="*"{print $3; exit}' "$STATE/leases")
      fi
      name=$(echo "$name" | tr -cd 'A-Za-z0-9._ -' | cut -c1-40)
      echo "$p|$net|$ip|$mac|$name" >> "$STATE/clients"
    done
  done
}

# ---------- take over the ports from ASUS ----------
TAKEOVER=$ROOT/asus-ports.backup
cmd_takeover(){
  [ -f "$TAKEOVER" ] && { say "VLAN Matrix already controls the ports"; return 0; }
  discover
  # 1) Copy the current ASUS port setup into ports.conf, so nothing changes
  touch "$CONF"
  for p in $(managed_ifaces); do
    exists "$p" || continue
    grep -q "^$p " "$CONF" && continue
    l=$(live_state "$p")
    # ASUS "Default" (Main untagged + all VLANs tagged) needs no line
    dflt=no
    case "$l" in main=U*) echo "$l" | grep -q '=O' || [ "$(echo "$l" | grep -o '=U' | wc -l)" != 1 ] || dflt=yes;; esac
    [ "$dflt" = yes ] && continue
    echo "$p $l" >> "$CONF"; log "migrated ASUS setup: $p $l"
  done
  # 2) Save the ASUS port settings and set every LAN port to Default
  nvram show 2>/dev/null | grep -E '^(vlan_trunklist|apg[0-9]+_dut_list)=' > "$TAKEOVER.tmp" && mv "$TAKEOVER.tmp" "$TAKEOVER"
  nvram set vlan_trunklist=""
  grep '^apg' "$TAKEOVER" | while IFS='=' read -r k v; do
    nv=$(echo "$v" | sed -E 's/(<[^>]*>[0-9]+>)[^<]*/\1/g'); [ "$nv" != "$v" ] && nvram set "$k=$nv"
  done
  nvram commit
  say "VLAN Matrix now controls the LAN ports. ASUS port settings saved; restarting network"
  ( sleep 2; service restart_net ) > /dev/null 2>&1 &
}
cmd_giveback(){
  [ -f "$TAKEOVER" ] || { say "ASUS already controls the ports"; return 0; }
  while IFS= read -r line; do nvram set "$line"; done < "$TAKEOVER"
  nvram commit; rm -f "$TAKEOVER"
  say "ASUS port settings restored; restarting network"
  ( sleep 2; service restart_net ) > /dev/null 2>&1 &
}

# ---------- status for the web page ----------
cmd_status(){
  discover
  collect_clients
  mkdir -p "$API"
  now=$(date +%s)
  {
    printf '{"version":"%s","time":%s,"req":"%s","msg":"%s",' "$VERSION" "$now" "${REQ:-}" "$(tail -n1 "$STATE/lastmsg" 2>/dev/null | sed 's/["\\]//g')"
    printf '"takeover":%s,' "$([ -f "$TAKEOVER" ] && echo true || echo false)"
    if [ -f "$DEADLINE" ]; then printf '"test":{"active":true,"left":%s},' $(( $(cat "$DEADLINE") - now )); else printf '"test":{"active":false},'; fi
    printf '"vlans":['
    sep=''
    while read vid br; do
      ipa=$(ip -4 -o addr show "$br" 2>/dev/null | awk '{print $4; exit}')
      printf '%s{"vid":%s,"br":"%s","ip":"%s"}' "$sep" "$vid" "$br" "$ipa"; sep=,
    done < "$STATE/vidmap"
    printf '],"ports":['
    sep=''
    W=$(wan_ifaces)
    port_map | while read label p kind; do
      exists "$p" || continue
      echo "$W" | grep -qx "$p" && kind=wan
      link=$(cat "/sys/class/net/$p/operstate" 2>/dev/null)
      spd=$(cat "/sys/class/net/$p/speed" 2>/dev/null); case "$spd" in ''|-*|*[!0-9]*) spd=0;; esac
      live=$(live_state "$p" | sed 's/\([a-z0-9]*\)=\([UTO]\)/"\1":"\2"/g; s/ /,/g')
      cl=$(awk -F'|' -v p="$p" '$1==p{printf "%s{\"net\":\"%s\",\"ip\":\"%s\",\"mac\":\"%s\",\"name\":\"%s\"}", (n++?",":""), $2,$3,$4,$5}' "$STATE/clients" | tr -d '\\')
      saved=$(grep "^$p " "$CONF" 2>/dev/null | cut -d' ' -f2- )
      test=$(grep "^$p " "$TESTCONF" 2>/dev/null | cut -d' ' -f2- )
      printf '%s{"label":"%s","if":"%s","kind":"%s","link":"%s","speed":%s,"live":{%s},"clients":[%s],"saved":"%s","test":"%s","managed":%s}' \
        "$sep" "$label" "$p" "${kind:-rj45}" "$link" "$spd" "$live" "$cl" "$saved" "$test" "$( { [ -n "$saved" ] || [ -n "$test" ]; } && echo true || echo false)"
      sep=,
    done
    printf ']}\n'
  } > "$API/.status.tmp" && mv "$API/.status.tmp" "$API/status.json"
}

# ---------- web page (menu tab) ----------
pick_page(){ # our page slot. Never a slot that another addon's menu tab points to (e.g. Skynet).
  # Our own tab line has already been removed from /tmp/menuTree.js, so any remaining userN.asp entry is someone else's.
  taken(){ grep -q "url: \"$1\"" /tmp/menuTree.js 2>/dev/null; }
  keep=none
  for f in /www/user/user*.asp; do
    [ -f "$f" ] && grep -q VLANMATRIX_V5_PAGE "$f" || continue
    n=${f##*/}
    if [ "$keep" = none ] && ! taken "$n"; then keep=$n; else rm -f "$f"; log "moved off $n (used by another addon or a duplicate)"; fi
  done
  [ "$keep" != none ] && { echo "$keep"; return; }
  i=1
  while [ $i -le 20 ]; do
    n=user$i.asp
    [ -e "/www/user/$n" ] || taken "$n" || { echo "$n"; return; }
    i=$((i+1))
  done
  echo none
}
webui(){
  mkdir -p "$API"
  [ -f /tmp/menuTree.js ] || cp /www/require/modules/menuTree.js /tmp/
  sed -i '/tabName: "VLAN Matrix"/d' /tmp/menuTree.js
  am_webui_page=$(pick_page)
  [ "$am_webui_page" = none ] && { log "no free web page slot"; return 1; }
  cp -f "$ROOT/vlanmatrix.asp" "/www/user/$am_webui_page"
  sed -i 's/{url: "Advanced_VLAN_Profile_Content.asp", tabName: "__INHERIT__"}/{url: "Advanced_VLAN_Profile_Content.asp", tabName: "VLAN Profiles"}/' /tmp/menuTree.js
  # The ASUS VLAN port tab stays visible (also after takeover). Un-hide it if an older version hid it.
  sed -i 's#^//\([[:space:]]*{url: "Advanced_VLAN_Switch_Content.asp"\)#\1#' /tmp/menuTree.js
  # Last tab of the VLAN group: VLAN · VLAN Profiles · VLAN Matrix
  sed -i "/url: \"Advanced_VLAN_Profile_Content.asp\"/a {url: \"$am_webui_page\", tabName: \"VLAN Matrix\"}," /tmp/menuTree.js
  # No ASUS VLAN page on this model/mode? Put the tab under Tools instead.
  grep -q 'tabName: "VLAN Matrix"' /tmp/menuTree.js || sed -i "/url: \"Tools_OtherSettings.asp\"/a {url: \"$am_webui_page\", tabName: \"VLAN Matrix\"}," /tmp/menuTree.js
  umount /www/require/modules/menuTree.js 2>/dev/null
  mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
  log "GUI: $am_webui_page"
}

wait_for_asus(){
  n=0
  while [ $n -lt 120 ]; do
    grep -q '^eth[0-9]*\.' /proc/net/vlan/config 2>/dev/null && [ -d /sys/class/net/br0/bridge ] && return 0
    sleep 2; n=$((n+2))
  done
}

# ---------- service-event from the web page ----------
gui_cmd(){ # $2 = vlanmatrix_<cmd>_<reqid>
  rest=${1#vlanmatrix_}; cmd=${rest%%_*}; REQ=${rest#*_}
  echo "$REQ" | grep -qE '^[0-9a-f]{1,16}$' || REQ=''
  cfg=$(sed -n 's/^vlanmatrix_cfg //p' /jffs/addons/custom_settings.txt 2>/dev/null)
  lock
  case "$cmd" in
    test)     ( cmd_test "$cfg" ) > "$STATE/lastmsg" 2>&1;;
    confirm)  ( cmd_confirm ) > "$STATE/lastmsg" 2>&1;;
    rollback) ( cmd_rollback ) > "$STATE/lastmsg" 2>&1;;
    refresh)  echo "Refreshed" > "$STATE/lastmsg";;
  esac
  cmd_status
}

[ -n "${VM_LIB:-}" ] && return 0
mkdir -p "$STATE"
case "${1:-}" in
  apply)    lock; do_apply; cmd_status;;
  test)     lock; cmd_test "${2:-}"; cmd_status;;
  confirm)  lock; cmd_confirm; cmd_status;;
  rollback) lock; cmd_rollback; cmd_status;;
  watchdog) lock; cmd_watchdog; cmd_status;;
  status)   lock; cmd_status; cat "$API/status.json";;
  webui)    webui;;
  takeover) lock; cmd_takeover; webui; cmd_status;;
  giveback) lock; cmd_giveback; webui; cmd_status;;
  boot)
    rm -f "$TESTCONF" "$SNAP" "$DEADLINE"   # a test never survives a reboot
    [ -f "$LOG" ] && tail -n 500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    ( wait_for_asus; webui; lock; do_apply; cmd_status
      cru a vlanmatrix_heal "*/5 * * * * /bin/sh $ROOT/vm.sh apply" ) > /dev/null 2>&1 &
    ;;
  event)    # service-event: commands from the web page
    case "$2:$3" in restart:vlanmatrix_*) gui_cmd "$3";; esac;;
  event-end) # service-event-end: ASUS rebuilt the network -> re-apply
    case "$3" in net|net_and_phy|lan|wireless|sdn*|vlan*|apg*|subnet|switch*|allnet*)
      ( sleep 8; /bin/sh "$ROOT/vm.sh" apply ) > /dev/null 2>&1 &;;
    esac;;
  *) sed -n '2,15p' "$0"; exit 1;;
esac
exit 0
