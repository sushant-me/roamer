const fs=require('fs'), path=require('path');
const p=path.join(__dirname,'..','assets','data','roamer_data.json');
const d=JSON.parse(fs.readFileSync(p,'utf8'));
const base={terrain:0.45,thermal:0.15,illumination:0.15,aridity:0.25};
const sites=d.sites;
function sim(s,w){
  const t=s.scores.terrain, th=s.scores.thermal, il=s.scores.illumination, ar=s.scores.aridity;
  const total=w.terrain+w.thermal+w.illumination+w.aridity;
  return (w.terrain*t + w.thermal*th + w.illumination*il + w.aridity*ar)/(total);
}
function ranks(w){
  const arr=sites.map(s=>({id:s.id, gap:sim(s,w)*(1-s.attention)*s.operability}));
  arr.sort((a,b)=>b.gap-a.gap);
  return arr.map(x=>x.id);
}
const variants=[];
for(const k of Object.keys(base)){
  for(const f of [0.8,1.2]){
    const w={...base}; w[k]=base[k]*f; variants.push(w);
  }
}
// pairwise correlated perturbations too
variants.push({terrain:0.45*1.15,thermal:0.15*1.15,illumination:0.15*0.85,aridity:0.25*0.85});
variants.push({terrain:0.45*0.85,thermal:0.15*0.85,illumination:0.15*1.15,aridity:0.25*1.15});
const topCounts={}; let kagbeniTop=0;
const baseRank=ranks(base);
for(const w of variants){
  const r=ranks(w); topCounts[r[0]]=(topCounts[r[0]]||0)+1; if(r[0]==='kagbeni') kagbeniTop++;
}
const sens={variants:variants.length, kagbeni_top:kagbeniTop, top_counts:topCounts,
  base_top:baseRank[0], base_order:baseRank,
  note:'Weights perturbed ±20% (single and paired); ranking recomputed from the same dimension scores. Experimental, not a full uncertainty propagation.'};
d.sensitivity=sens;
fs.writeFileSync(p,JSON.stringify(d,null,1));
console.log(JSON.stringify(sens,null,1));
