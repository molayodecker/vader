import {SEED, money, availability, safeLoad, refillSlot, updatePrice, toggleSlot} from './model.mjs';

const STORE_KEY='vader-ops-preview-v1';
let state=safeLoad(localStorage.getItem(STORE_KEY));
let connected=false;
let page='overview';
let selectedMachine=state.machines[0]?.id;
let search='';
const $=id=>document.getElementById(id);
const safe=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const product=id=>state.products.find(p=>p.id===id);
const machine=id=>state.machines.find(m=>m.id===id);
const badge=(label,type)=>`<span class="pill ${type}">${safe(label)}</span>`;
const stat=(label,value,icon,foot,warn=false)=>`<article class="stat"><div class="stat-label">${label}<span class="stat-icon">${icon}</span></div><div class="stat-value">${value}</div><div class="stat-foot ${warn?'warn':''}">${foot}</div></article>`;
const persist=()=>localStorage.setItem(STORE_KEY,JSON.stringify(state));
let toastTimer;
function toast(message){const el=$('toast');el.textContent=message;el.classList.add('show');clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.classList.remove('show'),3300);}
function setPage(next){page=next;search='';document.querySelectorAll('.nav').forEach(btn=>btn.classList.toggle('active',btn.dataset.page===page));render();}

function render(){
  $('mode-label').textContent=connected?'● PostgreSQL · read only':'● Prototype workspace';
  $('connect-api').textContent=connected?'Disconnect API':'Connect local API';
  const names={overview:'Overview',inventory:'Inventory',catalog:'Product catalog',machines:'Machines'};
  $('breadcrumb').textContent=names[page];
  $('page-title').innerHTML=page==='overview'?'Good morning, Molayo <span>✳</span>':safe(names[page]);
  $('page-subtitle').textContent={overview:'A clear view of your vending fleet, stock, and what needs attention.',
    inventory:'Manage your machine shelves and operator-entered stock estimates.',
    catalog:'Maintain your product prices and assortment.',
    machines:'View your machines and the state of their last reported telemetry.'}[page];
  $('view').innerHTML=({overview:renderOverview,inventory:renderInventory,catalog:renderCatalog,machines:renderMachines}[page])();
  if(connected) $('view').insertAdjacentHTML('afterbegin','<div class="note warning">PostgreSQL catalog preview · READ ONLY. Physical machine telemetry and safety are not verified.</div>');
}

function renderOverview(){
  const activeSlots=state.slots.filter(s=>s.enabled);
  const low=activeSlots.filter(s=>s.stock<=3);
  const productCount=state.products.length;
  const rows=state.machines.map(m=>`<div class="machine-row"><div class="machine-avatar">▣</div><div class="machine-meta"><strong>${safe(m.name)}</strong><small>${safe(m.id)} · ${safe(m.location)}</small></div>${badge(m.status==='demo'?'Demo only':'Unverified',m.status)}</div>`).join('');
  const alerts=low.map(s=>`<div class="alert-row"><div class="alert-icon">!</div><div class="machine-meta"><strong>${safe(product(s.productId)?.name||s.productId)} · Slot ${safe(s.slot)}</strong><small>${safe(s.machineId)} · ${s.stock} of ${s.capacity} units remaining</small></div>${badge(s.stock===0?'Sold out':'Low stock',s.stock===0?'sold':'low')}</div>`).join('');
  return `<div class="note warning">⚠ &nbsp; The physical machine is not connected. All values shown here are demo/operator-entered estimates, not verified live readings. The previously reported −39°C sensor value must be checked on-site.</div>
    <div class="stats">${stat('Registered machines',state.machines.length,'▣','1 real device ID · unverified')}${stat('Catalog products',productCount,'▤','Products available to configure')}${stat('Stock units',state.slots.reduce((n,s)=>n+s.stock,0),'▦','Across all demo shelves')}${stat('Needs attention',low.length,'!','Low or sold-out enabled shelves',true)}</div>
    <div class="grid-two"><section class="card"><div class="card-head"><div><h2>Machine overview</h2><div class="card-sub">Your registered vending fleet</div></div><button class="plain-btn" data-page-link="machines">View all →</button></div>${rows}</section>
    <section class="card"><div class="card-head"><div><h2>Stock alerts</h2><div class="card-sub">Shelves approaching empty</div></div><button class="plain-btn" data-page-link="inventory">Manage →</button></div>${alerts||'<div class="empty">No low-stock shelves</div>'}</section></div>`;
}

function machineSelect(){return `<label><span class="sr-only">Machine</span><select class="field" id="machine-select">${state.machines.map(m=>`<option value="${safe(m.id)}" ${m.id===selectedMachine?'selected':''}>${safe(m.name)}</option>`).join('')}</select></label>`;}
function renderInventory(){
  const rows=state.slots.filter(s=>s.machineId===selectedMachine && (`${s.slot} ${product(s.productId)?.name||''}`).toLowerCase().includes(search.toLowerCase()));
  const body=rows.map(s=>{const p=product(s.productId);const label=availability(s);const type=!s.enabled?'disabled':s.stock===0?'sold':s.stock<=3?'low':'good';
    return `<tr><td><strong>${safe(s.slot)}</strong></td><td><span class="product-icon">${safe(p?.image||'▧')}</span><span class="product-name"><strong>${safe(p?.name||'Unknown product')}</strong><small>${safe(p?.category||'')}</small></span></td><td>${money(p?.price||0)}</td>
      <td><strong>${s.stock} / ${s.capacity}</strong><div class="stock-meter"><span style="width:${Math.round(s.stock/s.capacity*100)}%"></span></div></td><td>${badge(label,type)}</td>
      <td><button class="outline-btn" data-action="stock" data-machine="${safe(s.machineId)}" data-slot="${safe(s.slot)}">Set stock</button> <button class="outline-btn" data-action="toggle" data-machine="${safe(s.machineId)}" data-slot="${safe(s.slot)}">${s.enabled?'Disable':'Enable'}</button></td></tr>`;}).join('');
  return `<div class="note">▣ &nbsp; Shelf capacities and stock here are configurable demo values. Refills are saved only in this browser; they do not update the vending machine.</div><div class="toolbar"><div class="toolbar-controls">${machineSelect()}<input class="field search" id="search" value="${safe(search)}" placeholder="Search products or slots" aria-label="Search products or slots"></div><div class="summary"><span class="metric-inline">Assigned shelves <strong>${rows.length}</strong></span></div></div>
  <section class="card table-wrap"><table><thead><tr><th>Slot</th><th>Product</th><th>Price</th><th>Stock</th><th>Status</th><th>Actions</th></tr></thead><tbody>${body||'<tr><td colspan="6" class="empty">No matching shelves</td></tr>'}</tbody></table></section>`;
}

function renderCatalog(){
  const rows=state.products.filter(p=>`${p.name} ${p.category}`.toLowerCase().includes(search.toLowerCase()));
  return `<div class="note">Prices are stored in integer pesewas internally. Editing a price here changes only this browser's preview, not historical orders or any live device.</div><div class="toolbar"><div class="toolbar-controls"><input class="field search" id="search" value="${safe(search)}" placeholder="Search your catalog" aria-label="Search catalog"></div><div class="summary"><span class="metric-inline">Products <strong>${rows.length}</strong></span></div></div>
  <section class="card table-wrap"><table><thead><tr><th>Product</th><th>Category</th><th>Price</th><th>Assigned shelves</th><th>Actions</th></tr></thead><tbody>${rows.map(p=>`<tr><td><span class="product-icon">${safe(p.image)}</span><span class="product-name"><strong>${safe(p.name)}</strong><small>${safe(p.id)}</small></span></td><td>${safe(p.category)}</td><td><strong>${money(p.price)}</strong></td><td>${state.slots.filter(s=>s.productId===p.id).length}</td><td><button class="outline-btn" data-action="price" data-product="${safe(p.id)}">Edit price</button></td></tr>`).join('')||'<tr><td colspan="5" class="empty">No products found</td></tr>'}</tbody></table></section>`;
}

function renderMachines(){
  return `<div class="note warning">No device telemetry is connected. The identified physical device's software version was 3.1.90, but its motor controller firmware and MDB host protocol remain unknown.</div>
  <div class="stats">${stat('Registered machines',state.machines.length,'▣','Configured machines')}${stat('Confirmed online',0,'⌁','No authenticated heartbeats')}${stat('Sensor confidence',0,'◉','Hardware not verified',true)}${stat('Live payments',0,'₵','No payment endpoints connected')}</div>
  <section class="card"><div class="card-head"><div><h2>Machine directory</h2><div class="card-sub">Connectivity and controller information</div></div></div>${state.machines.map(m=>`<div class="machine-row"><div class="machine-avatar">▣</div><div class="machine-meta"><strong>${safe(m.name)}</strong><small>${safe(m.id)} · ${safe(m.location)} · ${m.id==='M19265359'?'Upper software 3.1.90':'Sample machine'}</small></div>${badge(m.status==='demo'?'Demo data':'Awaiting hardware verification',m.status)}</div>`).join('')}</section>`;
}

document.addEventListener('click',event=>{
  const pageButton=event.target.closest('[data-page], [data-page-link]');
  if(pageButton){setPage(pageButton.dataset.page||pageButton.dataset.pageLink);return;}
  const button=event.target.closest('[data-action]');if(!button)return;
  if(connected){toast('Database mode is read only.');return;}
  try{
    const action=button.dataset.action;
    if(action==='toggle'){state=toggleSlot(state,button.dataset.machine,button.dataset.slot);toast('Demo shelf status updated.');}
    if(action==='stock'){
      const slot=state.slots.find(s=>s.machineId===button.dataset.machine&&s.slot===button.dataset.slot);
      const input=prompt(`New stock for ${slot.slot} (0–${slot.capacity}):`,String(slot.stock));
      if(input===null)return;
      state=refillSlot(state,slot.machineId,slot.slot,input);
      toast('Demo stock count updated.');
    }
    if(action==='price'){
      const p=product(button.dataset.product);
      const input=prompt(`Price for ${p.name} in GH₵:`,(p.price/100).toFixed(2));
      if(input===null)return;
      state=updatePrice(state,p.id,input);
      toast('Demo product price updated.');
    }
    persist();render();
  }catch(error){toast(error.message||'Could not save this change.');}
});

document.addEventListener('change',event=>{if(event.target.id==='machine-select'){selectedMachine=event.target.value;render();}});
document.addEventListener('input',event=>{if(event.target.id==='search'){
  const el=event.target;search=el.value;
  // Updating the table in place avoids stealing input focus on every keypress.
  const start=el.selectionStart;render();const replacement=$('search');replacement.focus();replacement.setSelectionRange(start,start);
}});

render();

$('connect-api').addEventListener('click',async()=>{
  if(connected){connected=false;document.body.classList.remove('api-connected');state=safeLoad(localStorage.getItem(STORE_KEY));selectedMachine=state.machines[0]?.id;render();return;}
  const token=prompt('Enter your local operator token (not saved):');if(!token)return;
  try{
    const response=await fetch('/api/snapshot',{headers:{Authorization:'Bearer '+token},cache:'no-store'});
    if(!response.ok)throw Error('API rejected request ('+response.status+')');
    const data=await response.json();
    if(data.source!=='postgres'||!Array.isArray(data.slots)||!Array.isArray(data.products)||!Array.isArray(data.machines))throw Error('Invalid API response');
    const ids=new Set([...data.machines.map(m=>m.id),...data.slots.map(s=>s.machine_id)]);
    const incoming={
      machines:[...ids].map(id=>({id,name:'Machine '+id,location:'Registered device',status:'unverified',temperature:null,lastSeen:null})),
      products:data.products.map(p=>({id:p.id,name:p.name,category:'Catalog',image:'▧',price:Number(p.price_minor)})),
      slots:data.slots.map(s=>({machineId:s.machine_id,slot:s.slot_code,productId:s.product_id,stock:Number(s.quantity),capacity:Number(s.capacity),enabled:s.enabled}))
    };
    if(incoming.slots.some(s=>!Number.isSafeInteger(s.stock)||!Number.isSafeInteger(s.capacity)||s.stock<0||s.capacity<1||s.stock>s.capacity))throw Error('Invalid inventory received');
    state=incoming;connected=true;document.body.classList.add('api-connected');selectedMachine=state.machines[0]?.id;render();toast('Connected: read-only PostgreSQL data.');
  }catch(error){toast(error.message);}
});
