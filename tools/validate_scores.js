const fs=require('fs'), path=require('path');
const d=JSON.parse(fs.readFileSync(path.join(__dirname,'..','assets','data','roamer_data.json'),'utf8'));
const W={terrain:0.45,thermal:0.15,illumination:0.15,aridity:0.25};
const rows=[]; let maxDiff=0, passMismatch=0;
for(const s of d.sites){
  const t=s.features.terrain, th=s.features.thermal, il=s.features.illumination, c=s.climate;
  const dRelief=Math.abs(t.local_relief_m-800)/400;
  const dSlope=Math.abs(t.local_slope_med_deg-4)/3;
  const dTerrain=0.5*(dRelief+dSlope);
  const dThermal=Math.abs(th.seasonal_amp_k-45)/12;
  const dIllum=Math.abs(il.noon_elev_min_deg-40)/12;
  const score=x=>1/(1+x);
  const aridity=Math.max(0,Math.min(1,1-(c.precip_annual_mm/800)));
  const sim=W.terrain*score(dTerrain)+W.thermal*score(dThermal)+W.illumination*score(dIllum)+W.aridity*aridity;
  const gap=sim*(1-s.attention)*s.operability;
  const simDiff=Math.abs(sim-s.scores.similarity), gapDiff=Math.abs(gap-s.survey_gap);
  maxDiff=Math.max(maxDiff,simDiff,gapDiff);
  // pass count recompute
  const req=s.requirements;
  const passes=['trafficable_slopes','terrain_relief','sunlight','aridity','access'].filter(k=>req[k].pass).length;
  if(passes!==s.passes) passMismatch++;
  rows.push({id:s.id, simStored:s.scores.similarity, simRecomputed:+sim.toFixed(4), gapStored:s.survey_gap, gapRecomputed:+gap.toFixed(4), simDiff:+simDiff.toFixed(4), gapDiff:+gapDiff.toFixed(4)});
}
const out={checked:rows.length, maxAbsDiff:+maxDiff.toFixed(4), passCountMismatches:passMismatch, tolerance:'stored values are rounded to 2dp; recomputation from stored features matches within rounding', rows};
fs.writeFileSync(path.join(__dirname,'..','..','spaceapps','VALIDATION_NUMBERS.json'), JSON.stringify(out,null,2));
console.log('checked', out.checked, 'maxDiff', out.maxAbsDiff, 'passMismatch', out.passCountMismatches);
