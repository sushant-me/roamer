const fs=require('fs'), path=require('path');
const p=path.join(__dirname,'..','assets','data','roamer_data.json');
const d=JSON.parse(fs.readFileSync(p,'utf8'));
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function count(q){
  const url='https://api.openalex.org/works?search='+encodeURIComponent(q)+'&per-page=1';
  for(let a=0;a<5;a++){
    const r=await fetch(url,{headers:{'User-Agent':'roamer-spaceapps/1.0 (mailto:sushant.poudel2028@gmail.com)'}});
    if(r.status===429){ await sleep(8000+a*4000); continue; }
    if(!r.ok) throw new Error('http '+r.status);
    const j=await r.json(); return j.meta.count;
  }
  throw new Error('rate limited');
}
(async()=>{
  for(const s of d.sites){
    try{
      const c=await count(s.name.split('(')[0].trim());
      s.literature={count:c, query:s.name.split('(')[0].trim()};
      s.attention=+Math.min(1, Math.log10(c+1)/4).toFixed(2);
      console.log(s.id, c, s.attention);
    }catch(e){ console.log(s.id,'FAIL',e.message); }
    await sleep(1200);
  }
  fs.writeFileSync(p,JSON.stringify(d,null,1));
  console.log('done');
})();
