const fs=require('fs'), path=require('path');
const p=path.join(__dirname,'..','assets','data','roamer_data.json');
const d=JSON.parse(fs.readFileSync(p,'utf8'));
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function count(q){
  const url='https://api.crossref.org/works?query.bibliographic='+encodeURIComponent(q)+'&rows=0&mailto=sushant.poudel2028@gmail.com';
  for(let a=0;a<4;a++){
    const r=await fetch(url,{headers:{'User-Agent':'roamer-spaceapps/1.0 (mailto:sushant.poudel2028@gmail.com)'}});
    if(r.status===429){ await sleep(3000); continue; }
    if(!r.ok) throw new Error('http '+r.status);
    const j=await r.json(); return j.message['total-results'];
  }
  throw new Error('rate limited');
}
(async()=>{
  let ok=0;
  for(const g of d.global_screening){
    try{
      const c=await count(g.name);
      const att=+Math.min(1, Math.log10(c+1)/4).toFixed(2);
      g.crossref_count=c; g.crossref_attention=att;
      g.secondary_gap=+(g.similarity*(1-att)*0.5).toFixed(2);
      ok++; console.log(g.id, c, att, g.secondary_gap);
    }catch(e){ console.log(g.id,'FAIL',e.message); }
    await sleep(800);
  }
  fs.writeFileSync(p,JSON.stringify(d,null,1));
  console.log('updated',ok);
})();
