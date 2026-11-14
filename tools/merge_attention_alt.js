const fs=require('fs'), path=require('path');
const p=path.join(__dirname,'..','assets','data','roamer_data.json');
const d=JSON.parse(fs.readFileSync(p,'utf8'));
const alt=JSON.parse(fs.readFileSync(path.join(__dirname,'..','..','spaceapps','ATTENTION_PROXY_CHECK.json'),'utf8'));
const map=Object.fromEntries(alt.rows.map(r=>[r.id,r.crossref_attention]));
let n=0;
for(const s of d.sites){
  if(map[s.id]===undefined) continue;
  s.attention_alt=map[s.id];
  s.gap_alt=+(s.scores.similarity*(1-map[s.id])*s.operability).toFixed(2);
  n++;
}
fs.writeFileSync(p,JSON.stringify(d,null,1));
console.log('merged alt attention for',n,'sites');
// print ranges for top 3
for(const s of d.sites.sort((a,b)=>b.survey_gap-a.survey_gap).slice(0,3)) console.log(s.id, s.attention, '->', s.attention_alt, 'gap', s.survey_gap, 'alt', s.gap_alt);
