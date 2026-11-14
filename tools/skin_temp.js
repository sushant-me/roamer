const fs=require('fs'), path=require('path');
const p=path.join(__dirname,'..','assets','data','roamer_data.json');
const d=JSON.parse(fs.readFileSync(p,'utf8'));
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function get(site){
  const url=`https://archive-api.open-meteo.com/v1/archive?latitude=${site.lat}&longitude=${site.lon}&start_date=2024-01-01&end_date=2024-12-31&hourly=soil_temperature_6cm&timezone=auto`;
  for(let a=0;a<4;a++){
    const r=await fetch(url);
    if(r.status===429){ await sleep(12000+a*4000); continue; }
    if(!r.ok) throw new Error('http '+r.status);
    return await r.json();
  }
  throw new Error('rate limited');
}
function stats(j){
  const t=j.hourly.time, v=j.hourly.soil_temperature_6cm;
  const months=Array.from({length:12},()=>[]);
  const daily={};
  for(let i=0;i<t.length;i++){
    const m=+t[i].slice(5,7)-1; const day=t[i].slice(0,10);
    if(Number.isFinite(v[i])){ months[m].push(v[i]); (daily[day]=daily[day]||[]).push(v[i]); }
  }
  const mean=a=>a.reduce((x,y)=>x+y,0)/a.length;
  const monthly=months.filter(a=>a.length).map(mean);
  const seasonal=(Math.max(...monthly)-Math.min(...monthly))/2;
  const diurnal=mean(Object.values(daily).map(a=>(Math.max(...a)-Math.min(...a))/2));
  return {seasonal:+seasonal.toFixed(1), diurnal:+diurnal.toFixed(1)};
}
(async()=>{
  let done=0;
  for(const s of d.sites){
    try{
      const j=await get(s); const st=stats(j);
      delete s.features.thermal.skin_seasonal_amp_k; delete s.features.thermal.skin_diurnal_amp_k;
      s.features.thermal.soil_seasonal_amp_k=st.seasonal;
      s.features.thermal.soil_diurnal_amp_k=st.diurnal;
      s.climate.soil_source='ERA5-Land soil temperature at 6 cm, 2024 (ground thermal context; not used in scoring).';
      done++; console.log(s.id, st.seasonal, st.diurnal);
    }catch(e){ console.log(s.id,'FAIL',e.message); }
    await sleep(700);
  }
  fs.writeFileSync(p,JSON.stringify(d,null,1));
  console.log('updated',done,'of',d.sites.length);
})();
