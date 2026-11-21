<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta http-equiv="Pragma" content="no-cache" />
<meta http-equiv="Expires" content="-1" />
<title>VLAN Matrix</title>
<!-- VLANMATRIX_V5_PAGE -->
<link rel="stylesheet" type="text/css" href="/index_style.css" />
<link rel="stylesheet" type="text/css" href="/form_style.css" />
<script type="text/javascript" src="/js/jquery.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/help.js"></script>
<script type="text/javascript" src="/js/httpApi.js"></script>
<style>
#vm{--bg:#0f161c;--card:#131c23;--line:#1f2a33;--mut:#8b9aa8;--txt:#e6edf3;--amber:#f2b84b;
 background:var(--bg);color:var(--txt);font:13px Inter,"Segoe UI",system-ui,-apple-system,sans-serif;padding:20px 22px;border-radius:14px;display:flex;flex-direction:column;gap:14px}
#vm *{box-sizing:border-box}
#vm .hd{display:flex;justify-content:space-between;align-items:center}
#vm .hd b{font-size:20px}
#vm .mut{color:var(--mut);font-size:11px}
#vm button{font:600 13px Inter,"Segoe UI",system-ui,sans-serif;height:36px;padding:0 14px;border-radius:8px;cursor:pointer}
#vm button:disabled{opacity:.4;cursor:default}
#vm .ghost{border:1px solid #2a3640;background:transparent;color:#c8d3dc}
#vm .pri{border:0;background:var(--amber);color:#0f161c;font-weight:700}
/* bagpanel */
#vm .panel{background:linear-gradient(#1b252e,#141c23);border:1px solid #26323c;border-radius:16px;padding:14px 10px 10px;display:flex;gap:4px;align-items:flex-end}
#vm .port{flex:1;display:flex;flex-direction:column;align-items:center;gap:5px;padding:8px 2px;border-radius:10px;background:transparent;border:1px solid transparent;cursor:pointer;color:var(--txt);height:auto;font-weight:400}
#vm .port:hover{background:#1b2630}
#vm .port.sel{background:#22303b;border-color:#3b4b58}
#vm .port.down{opacity:.45}
#vm .port.wan{cursor:default;opacity:.7;height:auto}
#vm .port.wan:hover{background:transparent}
#vm .led{width:10px;height:10px;border-radius:50%}
#vm .jack{width:42px;height:34px;border-radius:5px;background:#0a0f13;border:2px solid #36434e;display:flex;align-items:flex-end;justify-content:center}
#vm .jack i{width:20px;height:8px;background:#36434e;border-radius:2px 2px 0 0}
#vm .jack.sfp{width:42px;height:22px;margin-top:12px}
#vm .jack.sfp i{width:30px;height:6px}
#vm .bars{display:flex;gap:2px;height:6px}
#vm .bars span{width:5px;height:6px;border-radius:1px}
#vm .plabel{font-size:12px;font-weight:700;display:flex;align-items:center;gap:4px}
#vm .pend{width:6px;height:6px;border-radius:50%;background:var(--amber)}
#vm .legend{display:flex;gap:14px;flex-wrap:wrap;font-size:11px;color:var(--mut)}
#vm .legend span{display:inline-flex;align-items:center;gap:5px}
#vm .sq{width:9px;height:9px;border-radius:2px;display:inline-block}
/* editor */
#vm .grid{display:grid;grid-template-columns:minmax(0,3fr) minmax(0,2fr);gap:12px}
#vm .card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:14px 16px;display:flex;flex-direction:column;gap:8px}
#vm .row{display:flex;justify-content:space-between;align-items:center;padding:5px 0;border-top:1px solid #1a242c;gap:8px}
#vm .net{display:flex;flex-direction:column;gap:1px}
#vm .net b{display:flex;align-items:center;gap:8px;font-size:13px}
#vm .net small{font-size:10px;color:var(--mut);padding-left:17px}
#vm .seg{display:inline-flex;background:var(--bg);border:1px solid #2a3640;border-radius:9px;padding:3px;gap:3px}
#vm .seg button{height:28px;padding:0 10px;border:0;border-radius:7px;background:transparent;color:var(--mut);font-size:12px}
#vm .seg button.on{background:var(--txt);color:#0f161c}
#vm .seg button.chg{box-shadow:0 0 0 2px var(--amber)}
#vm .seg button.bad{box-shadow:0 0 0 2px #ff6b6b}
#vm .seg button:disabled{opacity:.25}
#vm .seg button.on:disabled{opacity:.6}
#vm .help{font-size:11px;line-height:1.45;color:#a9b8c5;background:#0f161c;border:1px solid #1f2a33;border-radius:8px;padding:8px 10px}
#vm .help b{color:#e6edf3}
#vm .sw{display:flex;align-items:center;gap:8px;font-size:12px;color:#c8d3dc;cursor:pointer}
#vm .dev{display:flex;flex-direction:column;gap:2px;padding:4px 0;border-top:1px solid #1a242c}
#vm .dev span:first-child{font-size:13px}
#vm .bar{display:flex;justify-content:space-between;align-items:center;background:#1b2530;border:1px solid #f2b84b55;border-radius:12px;padding:10px 14px;gap:10px}
#vm .test{background:#2a2410;border:1px solid var(--amber);border-radius:14px;padding:14px 16px;display:none;flex-direction:column;gap:8px}
#vm .test .t{display:flex;justify-content:space-between;align-items:baseline}
#vm .test .t span:last-child{font-size:22px;font-weight:700;font-variant-numeric:tabular-nums}
#vm .warn{background:#3a1717;border:1px solid #ff6b6b;border-radius:12px;padding:10px 14px;display:none}
#vm .note{background:var(--card);border:1px solid #2a3640;border-radius:12px;padding:10px 14px;display:none;color:#c8d3dc}
#vm code{background:#0a0f13;padding:2px 6px;border-radius:4px}
#vm .msg{color:var(--mut);font-size:12px;min-height:16px}
#vm .nets{display:flex;flex-direction:column;gap:6px}
#vm .netrow{display:flex;align-items:center;gap:10px;padding:6px 0;border-top:1px solid #1a242c}
#vm .netrow .grow{flex:1;display:flex;flex-direction:column;gap:1px}
#vm .netrow small{color:var(--mut);font-size:11px}
#vm .del{height:30px;padding:0 10px;font-size:12px;border:1px solid #5a2a2a;background:transparent;color:#ff9b9b}
#vm .addnet{display:flex;align-items:center;gap:10px;flex-wrap:wrap;padding-top:8px;border-top:1px solid #1a242c}
#vm .addnet input[type=number]{width:90px;height:32px;border-radius:8px;border:1px solid #2a3640;background:var(--bg);color:var(--txt);padding:0 8px;font:13px Inter,"Segoe UI",system-ui,sans-serif}
</style>
</head>
<body onload="initial();" class="bg">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<table class="content" align="center" cellpadding="0" cellspacing="0">
<tr><td width="17">&nbsp;</td>
<td valign="top" width="202"><div id="mainMenu"></div><div id="subMenu"></div></td>
<td valign="top">
<div id="tabMenu" class="submenuBlock"></div>
<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0"><tr><td align="left" valign="top">
<table width="760" border="0" cellpadding="4" cellspacing="0" class="FormTitle"><tbody><tr><td bgcolor="#4D595D" valign="top">
<div class="formfonttitle">LAN - VLAN Matrix</div>
<div style="margin:10px 0 10px 5px;" class="splitLine"></div>

<div id="vm">
 <div class="hd"><b>VLAN Matrix</b><span class="mut" id="vm-model">rear panel</span></div>
 <div class="panel" id="vm-panel"><span class="mut">Loading…</span></div>
 <div class="legend" id="vm-legend"></div>

 <div class="grid">
  <div class="card" id="vm-edit"></div>
  <div style="display:flex;flex-direction:column;gap:12px">
   <div class="card" id="vm-devs"></div>
   <div class="test" id="vm-test">
    <div class="t"><span style="font-weight:700;color:var(--amber)">Test running</span><span id="vm-left">5:00</span></div>
    <div style="font-size:12px;color:#d9cfb0">Check that everything works. It reverts by itself unless you keep it.</div>
    <div style="display:flex;gap:8px"><button type="button" class="pri" style="flex:1" id="vm-keep">Keep</button><button type="button" class="ghost" style="flex:1" id="vm-undo">Undo now</button></div>
   </div>
  </div>
 </div>

 <div class="bar" id="vm-bar">
  <div id="vm-chg" class="mut">No changes</div>
  <div style="display:flex;gap:8px"><button type="button" class="ghost" id="vm-discard" disabled>Discard</button><button type="button" class="pri" id="vm-go" disabled>Test for 5 min</button></div>
 </div>
 <div class="card" id="vm-nets">
  <b>Networks (VLAN profiles)</b>
  <div class="nets" id="vm-netlist"></div>
  <div class="addnet">
   <label for="vm-newvid" class="mut" style="font-size:12px">New VLAN ID</label>
   <input type="number" id="vm-newvid" min="3" max="4093" placeholder="3–4093">
   <label class="sw"><input type="checkbox" id="vm-newiso"> Isolate devices from each other</label>
   <button type="button" class="pri" id="vm-addnet">Add network</button>
  </div>
  <div class="help">Networks are created and deleted with the ASUS VLAN Profiles logic: the subnet is chosen automatically
   (192.168.&lt;VLAN ID&gt;.1/24 for IDs up to 254) with DHCP. The router restarts its network and Wi-Fi (about 1 minute).
   Wi-Fi names (SSIDs) for a network are set on the ASUS VLAN Profiles tab. A new network is Tagged on all ports until you change it.</div>
 </div>
 <div class="warn" id="vm-warn"></div>
 <div class="note" id="vm-asus"><b>ASUS' own VLAN port page is still active.</b> For one place to configure ports, run <code>/jffs/addons/vlanmatrix/vm.sh takeover</code> (your current setup is kept).</div>
 <div class="msg" id="vm-msg"></div>
 <div class="mut" id="vm-ver"></div>
</div>

</td></tr></tbody></table>
</td></tr></table>
</td><td width="10" align="center" valign="top">&nbsp;</td></tr>
</table>
<div id="footer"></div>
<script>
var COLORS=['#5aa9f0','#a78bfa','#f59e5b','#4cc38a','#f472b6','#e7d24a','#5fd3d3','#ff8a80','#b5d36a','#c49cff'];
var N={U:'Untagged',T:'Tagged',O:'Off'};
var S=null, edit={}, mg={}, sel=null, busy=false, bg=false, leftAt=0, timer=null;
function $id(i){return document.getElementById(i);}
function esc(s){return String(s==null?'':s).replace(/[&<>"]/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c];});}
function msg(t){$id('vm-msg').textContent=t||'';}
function keys(){return ['main'].concat(S.vlans.map(function(v){return String(v.vid);}));}
function netName(k){return k=='main'?'Main LAN':'VLAN '+k;}
function netColor(k){if(k=='main')return '#9aa7b3';var i=S.vlans.map(function(v){return String(v.vid);}).indexOf(k);return COLORS[i%COLORS.length];}
function netSub(k){if(k=='main')return 'br0';var v=S.vlans.filter(function(x){return String(x.vid)==k;})[0];return v?(v.ip||v.br):'';}
function parseLine(s){var o={};(s||'').split(' ').forEach(function(kv){var a=kv.split('=');if(a.length==2)o[a[0]]=a[1];});return o;}
function port(pi){return S.ports.filter(function(x){return x.if==pi;})[0];}
function base(p){var src=p.test?parseLine(p.test):(p.saved?parseLine(p.saved):{}),o={};keys().forEach(function(k){o[k]=src[k]||p.live[k]||'O';});return o;}
function cur(p){return edit[p.if]||base(p);}
function diffs(p){
 var out=[];
 if(!!mg[p.if]!==p.managed)out.push(mg[p.if]?'managed':'released');
 if(edit[p.if]){var b=base(p),e=edit[p.if];keys().forEach(function(k){if(b[k]!==e[k])out.push(netName(k)+' → '+N[e[k]]);});}
 return out;}
function changed(){return S.ports.some(function(p){return diffs(p).length>0;});}
function lan(){return S.ports.filter(function(p){return p.kind!='wan';});}
function shown(p){return mg[p.if]?cur(p):p.live;}

function drawPanel(){
 var h='';
 S.ports.forEach(function(p){
  var v=shown(p),led='#2a3640',bars='';
  keys().forEach(function(k){if(v[k]=='U')led=netColor(k);if(v[k]=='T')bars+='<span style="background:'+netColor(k)+'"></span>';});
  if(p.kind=='wan'){led='#d6dde3';bars='';}
  if(p.link!='up')led='#2a3640';
  var sp=p.speed?(p.speed>=1000?p.speed/1000+'G':p.speed+'M'):'';
  var wan=p.kind=='wan';
  h+='<button type="button" class="port'+(p.if==sel?' sel':'')+(p.link!='up'?' down':'')+(wan?' wan':'')+'" data-p="'+p.if+'" aria-label="'+p.label+(wan?' (WAN)':'')+'"'+(wan?' disabled title="Used as WAN – not managed"':'')+'>'+
   '<span class="led" style="background:'+led+';box-shadow:0 0 8px '+led+'"></span>'+
   '<span class="jack'+(p.kind=='sfp'?' sfp':'')+'"><i></i></span>'+
   '<span class="bars">'+bars+'</span>'+
   '<span class="plabel">'+p.label+(diffs(p).length?'<span class="pend"></span>':'')+'</span>'+
   '<span class="mut">'+(wan?'WAN':(p.link=='up'?sp:'no cable'))+'</span></button>';});
 $id('vm-panel').innerHTML=h;
 $id('vm-legend').innerHTML='<span>Light = untagged</span><span>Bars = tagged</span>'+keys().map(function(k){return '<span><i class="sq" style="background:'+netColor(k)+'"></i>'+netName(k)+'</span>';}).join('');
}
function drawEdit(){
 var p=port(sel); if(!p){$id('vm-edit').innerHTML='';return;}
 var on=!!mg[p.if], c=cur(p), b=base(p), ro=!on||S.test.active;
 var sp=p.speed?(p.speed>=1000?p.speed/1000+'G':p.speed+'M'):'';
 var h='<div style="display:flex;justify-content:space-between;align-items:center"><b style="font-size:15px">'+p.label+' <span class="mut" style="font-weight:400;font-size:12px">· '+p.if+(sp?' · '+sp:'')+' · '+(p.link=='up'?'link up':'no cable')+'</span></b>'+
  '<label class="sw"><input type="checkbox" id="vm-mg"'+(on?' checked':'')+(S.test.active?' disabled':'')+'> Manage</label></div>';
 h+='<div class="help">'+(on
  ?'<b>Managed:</b> VLAN Matrix keeps this port exactly as set here – at boot, after every ASUS network restart and every 5 minutes. '+
   'Untick to hand the port back to ASUS (takes effect at the next reboot or network restart). New VLANs stay Tagged here until you set them.'
  :'<b>Not managed:</b> this port follows '+(S.takeover?'the ASUS default (Main untagged, all VLANs tagged)':'the settings on the ASUS VLAN page')+'. The values below show the current state. '+
   'Tick <b>Manage</b> to control the port from here.')+'</div>';
 keys().forEach(function(k){
  var v=on?c[k]:p.live[k], mis=on&&!edit[p.if]&&!S.test.active&&p.saved&&c[k]!==p.live[k];
  var opts=k=='main'?['U','O']:['U','T','O'];
  h+='<div class="row"><span class="net"><b><i class="sq" style="background:'+netColor(k)+'"></i>'+netName(k)+'</b><small>'+esc(netSub(k))+'</small></span><span class="seg">'+
   ['U','T','O'].map(function(o){var dis=ro||opts.indexOf(o)<0, cl=(v==o?'on':'')+(on&&v==o&&b[k]!==o?' chg':'')+(mis&&v==o?' bad':'');
    return '<button type="button" class="'+cl+'" data-k="'+k+'" data-v="'+o+'"'+(dis?' disabled':'')+'>'+N[o]+'</button>';}).join('')+'</span></div>';});
 $id('vm-edit').innerHTML=h;
 var cl=p.clients||[];
 $id('vm-devs').innerHTML='<b>Devices on '+p.label+'</b>'+(cl.length?cl.map(function(x){return '<div class="dev" title="'+esc(x.mac)+'"><span>'+esc(x.name?x.name+' · ':'')+esc(x.ip||x.mac)+'</span><span class="mut">'+esc(x.net)+' · '+esc(x.mac)+'</span></div>';}).join(''):'<div class="mut">'+(p.link=='up'?'No devices seen':'No cable')+'</div>');
}
function draw(){
 drawPanel(); drawEdit(); drawNets();
 var ch=[];S.ports.forEach(function(p){var d=diffs(p);if(d.length)ch.push(p.label+': '+d.join(', '));});
 $id('vm-chg').innerHTML=ch.length?'<b style="color:var(--amber)">'+ch.length+' port'+(ch.length>1?'s':'')+' changed</b> <span class="mut">· '+esc(ch.join(' · '))+'</span>':'No changes';
 $id('vm-go').disabled=!ch.length||busy||S.test.active;
 $id('vm-discard').disabled=!ch.length;
 $id('vm-bar').style.display=S.test.active?'none':'flex';
 $id('vm-test').style.display=S.test.active?'flex':'none';
 var warn=[];S.ports.forEach(function(p){if(!p.saved||S.test.active)return;var c=base(p),bad=keys().filter(function(k){return c[k]!==p.live[k];});
  if(bad.length)warn.push(p.label+': '+bad.map(function(k){return netName(k)+' should be '+N[c[k]]+' but is '+N[p.live[k]];}).join(', '));});
 $id('vm-warn').style.display=warn.length?'block':'none';
 $id('vm-warn').innerHTML='<b>The router could not apply your saved setup</b><br>'+esc(warn.join(' | '))+'<br><span class="mut">See /jffs/addons/vlanmatrix/vlanmatrix.log</span>';
 $id('vm-asus').style.display=S.takeover?'none':'block';
 $id('vm-ver').textContent='VLAN Matrix v'+S.version+' · updated '+new Date(S.time*1000).toLocaleTimeString();
}
function setv(k,v){var p=port(sel),e=edit[sel]||JSON.parse(JSON.stringify(base(p)));
 if(v=='U')keys().forEach(function(x){if(e[x]=='U')e[x]='O';});
 e[k]=v;edit[sel]=e;draw();}
$id('vm').addEventListener('click',function(ev){
 var b=ev.target.closest('button');
 if(b&&b.classList.contains('port')){sel=b.getAttribute('data-p');draw();return;}
 if(b&&b.getAttribute('data-k')&&!b.disabled){setv(b.getAttribute('data-k'),b.getAttribute('data-v'));return;}
});
$id('vm').addEventListener('change',function(ev){
 if(ev.target.id=='vm-mg'){mg[sel]=ev.target.checked;if(mg[sel]&&!edit[sel])edit[sel]=JSON.parse(JSON.stringify(base(port(sel))));draw();}
});
function cfg(){return lan().filter(function(p){return mg[p.if];}).map(function(p){var c=cur(p);return p.if+':'+keys().map(function(k){return k+'='+c[k];}).join(',');}).join(';');}
function load(){return fetch('/user/vlanmatrix/status.json?'+Date.now(),{credentials:'same-origin'}).then(function(r){if(!r.ok)throw Error('status '+r.status);return r.json();});}
function adopt(s){S=s;mg={};edit={};S.ports.forEach(function(p){mg[p.if]=p.managed;});
 if(!sel||!port(sel)||port(sel).kind=='wan')sel=(lan().filter(function(p){return p.managed;})[0]||lan()[0]).if;
 leftAt=s.test.active?Date.now()+s.test.left*1000:0;if(s.msg)msg(s.msg);draw();tick();}
function tick(){clearInterval(timer);if(!leftAt)return;timer=setInterval(function(){
 var l=Math.max(0,Math.round((leftAt-Date.now())/1000));$id('vm-left').textContent=Math.floor(l/60)+':'+('0'+l%60).slice(-2);
 if(l<=0){clearInterval(timer);setTimeout(function(){load().then(adopt);},65000);}},1000);}
function send(cmd,c,quiet){
 // quiet = baggrundsopdatering: låser aldrig knapperne og overskriver aldrig dine ændringer
 if(quiet){if(busy||bg)return;bg=true;}else{if(busy)return;busy=true;draw();}
 function done(){if(quiet)bg=false;else busy=false;}
 var id=Math.random().toString(16).slice(2,10),page=location.pathname.split('/').pop();
 var f=new URLSearchParams({current_page:page,next_page:page,action_mode:'apply',action_wait:'2',action_script:'restart_vlanmatrix_'+cmd+'_'+id});
 if(c!==undefined)f.append('amng_custom',JSON.stringify({vlanmatrix_cfg:c}));
 if(!quiet)msg(cmd=='refresh'?'Reading ports and devices…':'Working…');
 fetch('/start_apply.htm',{method:'POST',credentials:'same-origin',body:f}).then(function(){
  var n=0;(function poll(){setTimeout(function(){load().then(function(s){
   if(s.req===id){done();
     if(quiet){ if(busy)return; if(changed()){S.ports=s.ports;S.time=s.time;S.test=s.test;draw();}else adopt(s); }
     else adopt(s);}
   else if(++n<40)poll();else{done();if(!quiet){msg('No answer from the router. Try again.');draw();}}
  }).catch(function(){if(++n<40)poll();else done();});},1000);})();
 }).catch(function(e){done();if(!quiet){msg('Error: '+e.message);draw();}});}
$id('vm-go').onclick=function(){send('test',cfg());};
$id('vm-keep').onclick=function(){send('confirm');};
$id('vm-undo').onclick=function(){send('rollback');};
$id('vm-discard').onclick=function(){edit={};mg={};S.ports.forEach(function(p){mg[p.if]=p.managed;});msg('Changes discarded');draw();};
setInterval(function(){if(S&&!busy&&document.visibilityState=='visible')send('refresh',undefined,true);},15000);
// ---- Networks: create / delete through the ASUS VLAN Profiles page (hidden), so the data is written exactly as ASUS does
function drawNets(){
 var h=S.vlans.length?'':'<div class="mut">No VLAN networks yet.</div>';
 S.vlans.forEach(function(v){var k=String(v.vid),users=S.ports.filter(function(p){var c=p.saved?parseLine(p.saved):{};return c[k]=='U'||c[k]=='T';}).map(function(p){return p.label;});
  h+='<div class="netrow"><i class="sq" style="background:'+netColor(k)+'"></i><span class="grow"><b>VLAN '+k+'</b><small>'+esc(v.ip||v.br)+(users.length?' · used on '+esc(users.join(', ')):'')+'</small></span>'+
   '<button type="button" class="del" data-del="'+k+'"'+(busy||S.test.active?' disabled':'')+'>Delete</button></div>';});
 $id('vm-netlist').innerHTML=h;
 $id('vm-addnet').disabled=busy||S.test.active;
}
function asusProfiles(run){ // load the ASUS page invisibly and hand its window to run(w)
 var f=document.createElement('iframe'); f.style.cssText='position:absolute;width:1px;height:1px;left:-9999px;border:0'; f.setAttribute('aria-hidden','true');
 var t0=Date.now(), done=false;
 function finish(err){if(done)return;done=true;setTimeout(function(){f.remove();},120000);if(err){busy=false;msg(err);draw();}}
 f.onload=function(){(function wait(){var w=f.contentWindow;
   if(w&&w.document&&w.document.getElementById('edit_vid')&&typeof w.addRow_Group=='function'){
    w.alert=function(m){finish('ASUS refused: '+m);}; w.confirm=function(){return true;};
    var api=w.httpApi, orig=api.nvramSet;
    api.nvramSet=function(obj,cb){orig.call(api,obj,function(){});
     msg('Saved. The router restarts its network and Wi-Fi – this page reloads in about a minute…');
     setTimeout(function(){location.reload();},75000);};
    try{run(w);}catch(e){finish('Error: '+e.message);}
   } else if(Date.now()-t0<20000) setTimeout(wait,300); else finish('Could not open the ASUS VLAN Profiles page.');})();};
 f.src='/Advanced_VLAN_Profile_Content.asp';
 document.body.appendChild(f);
}
$id('vm-addnet').onclick=function(){
 var vid=parseInt($id('vm-newvid').value,10);
 if(!(vid>=3&&vid<=4093)){msg('VLAN ID must be 3–4093.');return;}
 if(S.vlans.some(function(v){return v.vid==vid;})){msg('VLAN '+vid+' already exists.');return;}
 if(!confirm('Create VLAN '+vid+'?\nThe router restarts its network and Wi-Fi (about 1 minute).'))return;
 busy=true;draw();msg('Creating VLAN '+vid+'…');
 asusProfiles(function(w){w.document.getElementById('edit_vid').value=vid;w.document.getElementById('iso_checkbox').checked=$id('vm-newiso').checked;w.addRow_Group(w.sdn_maximum);});
};
$id('vm-netlist').addEventListener('click',function(ev){
 var b=ev.target.closest('button[data-del]'); if(!b||b.disabled)return;
 var vid=b.getAttribute('data-del');
 if(!confirm('Delete VLAN '+vid+'?\nIts Wi-Fi names (if any) are deleted too, and ports lose this network.\nThe router restarts its network (about 1 minute).'))return;
 busy=true;draw();msg('Deleting VLAN '+vid+'…');
 asusProfiles(function(w){
  var rows=w.document.querySelectorAll('#table_vlanProfile tr'),btn=null;
  for(var i=0;i<rows.length;i++){var c=rows[i].children;if(c.length>1&&c[1].textContent.trim()===String(vid)){btn=rows[i].querySelector('input[onclick*="del_Row"],.remove_btn');break;}}
  if(!btn)throw Error('VLAN '+vid+' not found on the ASUS page');
  w.del_Row(btn);});
});

function initial(){
 if(typeof show_menu==='function')show_menu();
 load().then(function(s){adopt(s);send('refresh',undefined,true);}).catch(function(){send('refresh');});
}
</script>
</body>
</html>
