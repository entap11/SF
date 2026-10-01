import assert from "node:assert/strict";
import crypto from "node:crypto";
import http from "node:http";
import express from "express";

async function main(): Promise<void> {
  const pair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const received: Array<{path: string; method: string; authorization: string; body: Record<string, unknown>}> = [];
  const rank = http.createServer(async (req, res) => {
    let body = ""; for await (const chunk of req) body += chunk;
    received.push({path: req.url!, method: req.method!, authorization: req.headers.authorization!, body: body ? JSON.parse(body) : {}});
    res.writeHead(200, {"Content-Type":"application/json"}).end(JSON.stringify({ok:true,enabled:true,quests:[]}));
  });
  await new Promise<void>((resolve)=>rank.listen(0,"127.0.0.1",resolve));
  const address=rank.address() as import("node:net").AddressInfo;
  process.env.VS_RANK_SERVICE_URL=`http://127.0.0.1:${address.port}`;
  process.env.VS_ENABLE_PLATFORM_ECONOMY_DELIVERY="true";
  process.env.VS_ENABLE_QUEST_DELIVERY="true";
  process.env.VS_QUEST_STARTS_AT="2026-09-28T00:00:00Z";
  process.env.VS_PLAYER_TOKEN_ISSUER="quest-test";
  process.env.VS_PLAYER_TOKEN_AUDIENCE="quest-test";
  process.env.VS_PLAYER_TOKEN_KEY_ID="quest-key";
  process.env.VS_PLAYER_TOKEN_PUBLIC_KEY_PEM=pair.publicKey.export({format:"pem",type:"spki"}).toString();
  const {handlePlatformEconomyPlayerAction}=await import("./platformEconomyPlayerHttp.js");
  const {config}=await import("./config.js");
  const app=express(); app.use(express.json());
  app.post("/:action",async(req,res)=>{if(!await handlePlatformEconomyPlayerAction(req.params.action,req,res))res.sendStatus(404);});
  const server=await new Promise<http.Server>((resolve)=>{const s=app.listen(0,"127.0.0.1",()=>resolve(s));});
  const port=(server.address() as import("node:net").AddressInfo).port;
  const player="0190f47a-1234-7abc-8def-123456789abc";
  const encode=(value:unknown)=>Buffer.from(JSON.stringify(value)).toString("base64url");
  const token=(scopes:string[])=>{
    const now=Math.floor(Date.now()/1000);
    const input=encode({alg:"ES256",typ:"JWT",kid:"quest-key"})+"."+encode({iss:"quest-test",aud:"quest-test",sub:player,
      sid:"0190f47a-3234-7abc-8def-123456789abc",did:"0190f47a-4234-7abc-8def-123456789abc",jti:"quest-jti",
      iat:now,nbf:now-1,exp:now+600,ver:1,scp:scopes});
    return input+"."+crypto.sign("sha256",Buffer.from(input),{key:pair.privateKey,dsaEncoding:"ieee-p1363"}).toString("base64url");
  };
  const valid=token(["economy:read","progression:claim"]);
  async function post(action:string,body:Record<string,unknown>={},auth=valid){
    return fetch(`http://127.0.0.1:${port}/${action}`,{method:"POST",headers:{"Content-Type":"application/json",Authorization:`Bearer ${auth}`},body:JSON.stringify(body)});
  }
  try {
    assert.equal((await post("get_quests",{},"")).status,401);
    assert.equal((await post("claim_quest",{},token(["economy:read"]))).status,403);
    assert.equal((await post("get_quests",{player_id:"someone-else"})).status,403);
    assert.equal(received.length,0);
    const read=await post("get_quests");
    assert.equal(read.status,200); assert.equal(read.headers.get("cache-control"),"no-store");
    assert.equal(received[0].path,"/v1/platform/quests/me"); assert.equal(received[0].method,"GET");
    const intent={epoch_id:"test",quest_id:"daily_mix",cycle_start:"2026-09-29T00:00:00Z",request_id:"claim-fixed"};
    assert.equal((await post("claim_quest",{...intent,progress:999,reward:{honey_centi:999999},player_id:player})).status,200);
    assert.deepEqual(received[1].body,intent);
    assert.equal(received[1].authorization,`Bearer ${valid}`);
    assert.equal(received[1].path,"/v1/platform/quests/claim");
    config.enableQuestDelivery=false;
    assert.equal((await post("get_quests")).status,503);
    assert.equal((await post("claim_quest",intent)).status,503);
    assert.equal(received.length,2);
    console.log(JSON.stringify({ok:true,smoke:"quest_http_proxy",identity_scope_enforced:true,client_rewards_discarded:true,disabled_blocks_proxy:true}));
  } finally {
    for(const s of [server,rank]) {s.closeAllConnections();await new Promise<void>((resolve)=>s.close(()=>resolve()));}
  }
}
void main().catch((error)=>{console.error(error);process.exitCode=1;});
