const fs=require('fs'), path=require('path');
const p=path.join(__dirname,'..','assets','data','roamer_data.json');
const d=JSON.parse(fs.readFileSync(p,'utf8'));
const base={slope:10, reliefLo:20, reliefHi:1500, sun:20, aridity:800, access:0.5};
const variants=[
 {slope:8},{slope:12},{reliefLo:16,reliefHi:1200},{reliefLo:24,reliefHi:1800},
 {sun:16},{sun:24},{aridity:640},{aridity:960},{access:0.4},{access:0.6}
];
function passes(s,v){
  const r=s.requirements; const t={...base,...v};
  return {
    trafficable_slopes: r.trafficable_slopes.value <= t.slope,
    terrain_relief: r.terrain_relief.value >= t.reliefLo && r.terrain_relief.value <= t.reliefHi,
    sunlight: r.sunlight.value >= t.sun,
    aridity: r.aridity.value < t.aridity,
    access: r.access.value >= t.access,
  };
}
let flips=0; const affected=new Set();
const basePass=Object.fromEntries(d.sites.map(s=>[s.id,passes(s,{})]));
for(const v of variants){
  for(const s of d.sites){
    const pp=passes(s,v);
    for(const k of Object.keys(pp)) if(pp[k]!==basePass[s.id][k]){flips++; affected.add(s.id+':'+k);}
  }
}
const out={variants:variants.length, flips, affected:affected.size,
 note:'Thresholds change pass/fail labels, not the Survey Gap ranking: the gap is computed from continuous distance scores, not from pass counts. This reports pass-count sensitivity so labels are not over-read.'};
d.sensitivity={...(d.sensitivity||{}), thresholds:out};
fs.writeFileSync(p,JSON.stringify(d,null,1));
console.log(JSON.stringify(out,null,1));
