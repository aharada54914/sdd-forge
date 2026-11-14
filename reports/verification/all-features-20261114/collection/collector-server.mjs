import http from 'node:http';
import {webcrypto} from 'node:crypto';
import worker from '../.sites-checkout/worker/index.js';
globalThis.crypto ??= webcrypto;
const records = new Map(); let version = 0;
const env = {SDD_PUBLISHER_TOKEN:'bounded-local-test-only', SDD_COLLECTOR_TOKEN:'bounded-local-collector-test-token-12345', BUCKET:{
 async get(key) { const value=records.get(key); return value ? {etag:value.etag,text:async()=>value.body,json:async()=>JSON.parse(value.body)} : null; },
 async put(key,body,options={}) { const old=records.get(key), condition=options.onlyIf;
  if (condition?.etagMatches && old?.etag!==condition.etagMatches) return null;
  if (condition?.etagDoesNotMatch==='*' && old) return null;
  const value={body,etag:String(++version)}; records.set(key,value); return value;
 }
}};
http.createServer(async(req,res)=>{
 try {
  const chunks=[];for await(const chunk of req)chunks.push(chunk);const body=Buffer.concat(chunks);
  const headers={...req.headers};
  // This bridge is loopback-only QA; it never sends a synthetic identity to production.
  if (req.method==='GET' && !headers['x-sdd-publisher'])headers['oai-authenticated-user-id']='local-qa-viewer';
  const response=await worker.fetch(new Request('http://127.0.0.1:8792'+req.url,{method:req.method,headers,...(body.length?{body}:{})}),env);
  res.writeHead(response.status,Object.fromEntries(response.headers));res.end(Buffer.from(await response.arrayBuffer()));
 }catch {res.writeHead(500);res.end('{}');}
}).listen(8792,'127.0.0.1',()=>console.log('collector QA bridge ready on loopback 8792'));
