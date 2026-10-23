export const SEED = Object.freeze({
  machines: [
    {id:'M19265359', name:'Accra · Food & Drinks', location:'Accra, Ghana', status:'unverified', temperature:null, lastSeen:null},
    {id:'DEMO-002', name:'Airport Lounge', location:'Demo location', status:'demo', temperature:4.2, lastSeen:'Demo data'},
  ],
  products: [
    {id:'water',name:'Still Water',category:'Drinks',price:500,image:'💧'},
    {id:'juice',name:'Orange Juice',category:'Drinks',price:1200,image:'🍊'},
    {id:'sandwich',name:'Chicken Sandwich',category:'Food',price:2800,image:'🥪'},
    {id:'yogurt',name:'Greek Yogurt',category:'Food',price:1950,image:'🥛'},
    {id:'fruit',name:'Fresh Fruit Cup',category:'Food',price:1600,image:'🍓'},
  ],
  slots: [
    {machineId:'M19265359',slot:'A1',productId:'water',stock:8,capacity:10,enabled:true},
    {machineId:'M19265359',slot:'A2',productId:'juice',stock:3,capacity:10,enabled:true},
    {machineId:'M19265359',slot:'B1',productId:'sandwich',stock:1,capacity:8,enabled:true},
    {machineId:'M19265359',slot:'B2',productId:'yogurt',stock:0,capacity:8,enabled:true},
    {machineId:'M19265359',slot:'C1',productId:'fruit',stock:5,capacity:8,enabled:false},
    {machineId:'DEMO-002',slot:'A1',productId:'water',stock:10,capacity:10,enabled:true},
  ],
});

export const money = minor => `GH₵ ${(minor / 100).toFixed(2)}`;
export const availability = slot => !slot.enabled ? 'Disabled' : slot.stock === 0 ? 'Sold out' : slot.stock <= 3 ? 'Low stock' : 'In stock';

export function validateStock(quantity, capacity) {
  const n = Number(quantity);
  if (!Number.isSafeInteger(n) || n < 0 || n > capacity) throw new Error(`Stock must be between 0 and ${capacity}.`);
  return n;
}

export function refillSlot(state, machineId, slotCode, quantity) {
  const slot = state.slots.find(s => s.machineId === machineId && s.slot === slotCode);
  if (!slot) throw new Error('Slot not found.');
  const nextStock = validateStock(quantity, slot.capacity);
  return {...state, slots: state.slots.map(s => s === slot ? {...s,stock:nextStock} : s)};
}

export function updatePrice(state, productId, priceGhs) {
  const price = Number(priceGhs);
  if (!Number.isFinite(price) || price <= 0 || !Number.isSafeInteger(Math.round(price * 100)) ||
      Math.abs(price * 100 - Math.round(price * 100)) > 0.000001)
    throw new Error('Enter a valid positive price with at most two decimal places.');
  if (!state.products.some(p => p.id === productId)) throw new Error('Product not found.');
  const minor = Math.round(price * 100);
  return {...state,products:state.products.map(p => p.id === productId ? {...p,price:minor} : p)};
}

export function toggleSlot(state, machineId, slotCode) {
  if (!state.slots.some(s => s.machineId === machineId && s.slot === slotCode)) throw new Error('Slot not found.');
  return {...state, slots:state.slots.map(s => s.machineId === machineId && s.slot === slotCode ? {...s,enabled:!s.enabled} : s)};
}

export function safeLoad(raw) {
  if (!raw) return structuredClone(SEED);
  try {
    const candidate = JSON.parse(raw);
    if (!candidate || !Array.isArray(candidate.machines) || !Array.isArray(candidate.products) ||
        !Array.isArray(candidate.slots) || candidate.slots.some(s => !Number.isSafeInteger(s.stock) ||
          !Number.isSafeInteger(s.capacity) || s.stock < 0 || s.capacity < 1 || s.stock > s.capacity))
      throw new Error('Invalid demo state');
    return candidate;
  } catch { return structuredClone(SEED); }
}
