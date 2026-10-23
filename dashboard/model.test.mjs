import test from 'node:test';
import assert from 'node:assert/strict';
import {SEED, safeLoad, refillSlot, updatePrice, toggleSlot, availability} from './model.mjs';

test('refills a specific machine slot without changing the input state', () => {
  const state = structuredClone(SEED);
  const result = refillSlot(state, 'M19265359', 'A2', 7);
  assert.equal(result.slots[1].stock, 7);
  assert.equal(state.slots[1].stock, 3);
  assert.equal(result.slots.at(-1).stock, 10);
});

test('stock cannot be negative, fractional or exceed capacity', () => {
  for(const quantity of [-1, 11, 3.2, 'not a number'])
    assert.throws(() => refillSlot(SEED, 'M19265359', 'A1', quantity));
});

test('price update uses integer pesewas and rejects invalid amounts', () => {
  assert.equal(updatePrice(SEED, 'water', '6.50').products[0].price, 650);
  for(const value of [0, -1, 'abc', '2.125'])
    assert.throws(() => updatePrice(SEED, 'water', value));
});

test('slot disable and low-stock states are explicit', () => {
  assert.equal(availability(SEED.slots[2]), 'Low stock');
  assert.equal(availability(SEED.slots[3]), 'Sold out');
  assert.equal(availability(toggleSlot(SEED,'M19265359','A1').slots[0]), 'Disabled');
});

test('invalid cached data resets to demo fixtures', () => {
  assert.equal(safeLoad('{broken').machines.length, 2);
  assert.equal(safeLoad(JSON.stringify({machines:[],products:[],slots:[{stock:-1,capacity:1}]})).slots.length, 6);
});
