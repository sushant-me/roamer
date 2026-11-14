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
  const rows=[];
  for(const s of d.sites){
    const q=s.name.split('(')[0].replace(/—.*/,'').trim();
    try{
      const c=await count(q);
      const att=+Math.min(1, Math.log10(c+1)/4).toFixed(2);
      rows.push({id:s.id,name:q,openalex:s.attention, crossref:c, crossref_attention:att});
      console.log(s.id, c, att, 'vs', s.attention);
    }catch(e){ console.log(s.id,'FAIL',e.message); }
    await sleep(700);
  }
  // correlation
  const xs=rows.map(r=>r.openalex), ys=rows.map(r=>r.crossref_attention);
  const mean=a=>a.reduce((x,y)=>x+y,0)/a.length;
  const mx=mean(xs), my=mean(ys);
  let num=0,dx=0,dy=0; for(let i=0;i<xs.length;i++){num+=(xs[i]-mx)*(ys[i]-my);dx+=(xs[i]-mx)**2;dy+=(ys[i]-my)**2;}
  const pearson=num/Math.sqrt(dx*dy);
  const out={rows, pearson:+pearson.toFixed(3), note:'Crossref bibliographic query counts vs OpenAlex works counts; different databases and query semantics — this is a proxy-sensitivity check, not a replacement.'};
  fs.writeFileSync(path.join(__dirname,'..','..','spaceapps','ATTENTION_PROXY_CHECK.json'), JSON.stringify(out,null,2));
  console.log('pearson', pearson.toFixed(3));
})();
