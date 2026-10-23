import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {resolve, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createApi} from './routes.mjs';

const token=process.env.VADER_OPERATOR_TOKEN;
const url=process.env.DATABASE_URL;
const port=Number(process.env.VADER_PORT||8080);
if(!url||!token||token.length<32||!Number.isInteger(port)||port<1||port>65535)
  throw Error('Set DATABASE_URL and VADER_OPERATOR_TOKEN (32+ characters)');
const {Pool}=await import('pg');
const pool=new Pool({connectionString:url,max:5,connectionTimeoutMillis:3000,statement_timeout:5000});
const api=createApi({query:sql=>pool.query(sql),token});
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const assets=new Map([['/','index.html'],['/index.html','index.html'],['/app.mjs','app.mjs'],['/model.mjs','model.mjs'],['/styles.css','styles.css']]);
const server=createServer(async(req,res)=>{
  if(req.url?.startsWith('/api/')) return api(req,res);
  if(req.method!=='GET'||!assets.has(req.url)){res.writeHead(404);res.end('Not found');return;}
  try{
    const filename=assets.get(req.url);
    const content=await readFile(resolve(root,filename));
    const type=filename.endsWith('.html')?'text/html':filename.endsWith('.css')?'text/css':'text/javascript';
    res.writeHead(200,{'Content-Type':type+'; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff',
      'Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"});
    res.end(content);
  }catch{res.writeHead(500);res.end('Asset error');}
});
server.listen(port,'127.0.0.1',()=>process.stdout.write('Vader local console: http://127.0.0.1:'+port+'\n'));
process.on('SIGINT',()=>server.close(()=>pool.end()));
