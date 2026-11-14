const fs=require('fs'), path=require('path');
const p=path.join(__dirname,'..','assets','data','roamer_data.json');
const d=JSON.parse(fs.readFileSync(p,'utf8'));
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
  let ok=0;
  for(const s of d.sites){
    const url=`https://power.larc.nasa.gov/api/temporal/climatology/point?parameters=TS,T2M&community=RE&longitude=${s.lon}&latitude=${s.lat}&format=JSON`;
    try{
      const r=await fetch(url); if(!r.ok) throw new Error('http '+r.status);
      const j=await r.json(); const ts=j.properties.parameter.TS;
      const months=['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
      const vals=months.map(m=>ts[m]).filter(v=>typeof v==='number');
      const amp=(Math.max(...vals)-Math.min(...vals))/2;
      s.features.thermal.skin_seasonal_amp_k=+amp.toFixed(1);
      s.climate.skin_source='MERRA-2 Earth skin temperature (NASA POWER monthly climatology). Context only; scoring uses ERA5 air temperature.';
      ok++; console.log(s.id, amp.toFixed(1));
    }catch(e){ console.log(s.id,'FAIL',e.message); }
    await sleep(300);
  }
  fs.writeFileSync(p,JSON.stringify(d,null,1));
  console.log('updated',ok,'of',d.sites.length);
})();
