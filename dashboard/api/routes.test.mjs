import test from 'node:test';
import assert from 'node:assert/strict';
import {createApi} from './routes.mjs';
const token='example-operator-token-longer-than-32-characters';
const req=(auth,method='GET',url='/api/snapshot')=>({method,url,headers:{authorization:auth}});
function response(){return {status:null,body:null,headers:{},setHeader(k,v){this.headers[k]=v;},writeHead(v){this.status=v;},end(v){this.body=JSON.parse(v);}};}
test('authorization is mandatory before any database query',async()=>{
  let called=0;const api=createApi({token,query:async()=>{called++;return {rows:[]};}});
  for(const auth of [undefined,'Bearer wrong','Basic '+token]){const res=response();await api(req(auth),res);assert.equal(res.status,401);}
  assert.equal(called,0);
});
test('read-only route returns tables',async()=>{
  let count=0;const api=createApi({token,query:async()=>{count++;return {rows:[]};}});
  const ok=response();await api(req('Bearer '+token),ok);
  assert.equal(ok.status,200);assert.equal(ok.body.source,'postgres');assert.equal(count,3);
  const denied=response();await api(req('Bearer '+token,'PATCH'),denied);
  assert.equal(denied.status,405);
});
test('database errors are redacted',async()=>{
  const api=createApi({token,query:async()=>{throw Error('SECRET_SQL_PASSWORD');}});
  const res=response();await api(req('Bearer '+token),res);
  assert.equal(res.status,503);assert.equal(JSON.stringify(res.body).includes('SECRET'),false);
});
