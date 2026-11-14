// Rank the seven global analogs with OpenAlex attention once the daily budget resets.
// Run: node tools/rank_global.js
const fs=require('fs'), path=require('path');
const p=path.join(__dirname,'..','assets','data','roamer_data.json');
const d=JSON.parse(fs.readFileSync(p,'utf8'));
const BASE=process.env.OPENALEX_BASE||'https://api.openalex.org';
const OPERABILITY={rio_tinto:0.6,haughton:0.1,dry_valleys:0.05,la_joya:0.5,wadi_rum:0.6,death_valley:0.5,askja:0.5};
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function count(q){
  const url=BASE+'/works?search='+encodeURIComponent(q)+'&per-page=1&mailto=sushant.poudel2028@gmail.com';
  for(let a=0;a<6;a++){
    const r=await fetch(url,{headers:{'User-Agent':'roamer-spaceapps/1.0 (mailto:sushant.poudel2028@gmail.com)'}});
    if(r.status===429){ await sleep(15000+a*5000); continue; }
    if(!r.ok) throw new Error('http '+r.status);
    const j=await r.json(); if(!j.meta||typeof j.meta.count!=='number') throw new Error('no meta.count');
    return j.meta.count;
  }
  throw new Error('rate limited after retries');
}
(async()=>{
  if(process.env.ROAMER_TEST_BLOCKED==='1'){ console.log('TEST: simulated blocked run — exiting without writing'); process.exit(2); }
  let ok=0, fail=0;
  for(const g of d.global_screening){
    try{
      const c=await count(g.name);
      const att=+Math.min(1, Math.log10(c+1)/4).toFixed(2);
      g.openalex_count=c;
      g.openalex_attention=att;
      g.openalex_gap=+(g.similarity*(1-att)*OPERABILITY[g.id]).toFixed(2);
      ok++; console.log(g.id, c, 'att', att, 'gap', g.openalex_gap);
    }catch(e){ fail++; console.log(g.id,'FAIL',e.message); }
    await sleep(1200);
  }
  if(ok !== d.global_screening.length || fail > 0){
    console.log('PARTIAL/FAILED:', ok, 'ok,', fail, 'failed — NOT writing data (retry after 05:45 NPT)');
    process.exit(2);
  }
  fs.copyFileSync(p, p.replace(/\.json$/,'.backup.json'));
  fs.writeFileSync(p,JSON.stringify(d,null,1));
  console.log('openalex-ranked',ok,'failed',fail,'— wrote data (backup saved)');
})();
