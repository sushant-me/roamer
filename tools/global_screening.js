const fs=require('fs'), path=require('path');
const { mosaic, metersPerPixel } = require('./lib_geo');
const SITES=[
 {id:'rio_tinto',name:'Río Tinto',country:'Spain',lat:37.69,lon:-6.60,alt:100},
 {id:'haughton',name:'Haughton Crater',country:'Canada',lat:75.37,lon:-89.68,alt:200},
 {id:'dry_valleys',name:'McMurdo Dry Valleys',country:'Antarctica',lat:-77.53,lon:162.17,alt:500},
 {id:'la_joya',name:'Pampas de La Joya',country:'Peru',lat:-16.60,lon:-71.80,alt:1400},
 {id:'wadi_rum',name:'Wadi Rum',country:'Jordan',lat:29.58,lon:35.42,alt:900},
 {id:'death_valley',name:'Death Valley',country:'USA',lat:36.46,lon:-116.87,alt:0},
 {id:'askja',name:'Askja',country:'Iceland',lat:65.03,lon:-16.75,alt:500},
];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function climate(s){
  const url=`https://archive-api.open-meteo.com/v1/archive?latitude=${s.lat}&longitude=${s.lon}&start_date=2015-01-01&end_date=2024-12-31&daily=precipitation_sum,temperature_2m_max,temperature_2m_min&timezone=auto`;
  for(let a=0;a<5;a++){
    const r=await fetch(url);
    if(r.status===429){ await sleep(12000+a*5000); continue; }
    if(!r.ok) throw new Error('http '+r.status);
    const j=await r.json(); const d=j.daily;
    const sum=a=>a.reduce((x,y)=>x+y,0), mean=a=>sum(a)/a.length;
    const precip=sum(d.precipitation_sum)/10;
    const months=Array.from({length:12},()=>[]);
    d.time.forEach((t,i)=>{ months[+t.slice(5,7)-1].push((d.temperature_2m_max[i]+d.temperature_2m_min[i])/2); });
    const monthly=months.map(a=>mean(a));
    const seasonal=(Math.max(...monthly)-Math.min(...monthly))/2;
    return {precip:+precip.toFixed(0), seasonal:+seasonal.toFixed(1)};
  }
  throw new Error('climate rate limited');
}
function solar(lat){
  const decl=day=>23.45*Math.sin(2*Math.PI*(284+day)/365);
  const noon=day=>90-Math.abs(lat-decl(day));
  return Math.min(noon(355),noon(172));
}
async function terrain(s){
  const z=12, halfKm=6;
  const dLat=halfKm/111, dLon=halfKm/(111*Math.cos(s.lat*Math.PI/180));
  const m=await mosaic(z,s.lon-dLon,s.lon+dLon,s.lat-dLat,s.lat+dLat);
  const res=metersPerPixel(s.lat,z), cellPx=Math.max(2,Math.round(500/res));
  const NX=Math.floor(m.W/cellPx), NY=Math.floor(m.H/cellPx);
  const cells=Array.from({length:NY},()=>new Float64Array(NX));
  for(let cy=0;cy<NY;cy++)for(let cx=0;cx<NX;cx++){
    let sum=0,n=0;
    for(let py=0;py<cellPx;py++)for(let px=0;px<cellPx;px++){
      const v=m.grid[(cy*cellPx+py)*m.W+(cx*cellPx+px)]; if(Number.isFinite(v)){sum+=v;n++;}
    }
    cells[cy][cx]=n?sum/n:NaN;
  }
  const vals=[]; for(const r of cells)for(const v of r) if(Number.isFinite(v)) vals.push(v);
  vals.sort((a,b)=>a-b); const q=p=>vals[Math.min(vals.length-1,Math.floor(p*(vals.length-1)))];
  const local=[];
  const cxs=Math.floor(NX/2), cys=Math.floor(NY/2);
  for(let y=cys-1;y<=cys+1;y++)for(let x=cxs-1;x<=cxs+1;x++){
    if(y<1||x<1||y>=NY-1||x>=NX-1) continue;
    const a=cells[y-1][x-1],b=cells[y-1][x],c=cells[y-1][x+1],d=cells[y][x-1],e=cells[y][x+1],f=cells[y+1][x-1],g=cells[y+1][x],h=cells[y+1][x+1];
    if([a,b,c,d,e,f,g,h].some(v=>!Number.isFinite(v))) continue;
    const dzdx=((c+2*e+h)-(a+2*d+f))/(8*500), dzdy=((f+2*g+h)-(a+2*b+c))/(8*500);
    local.push(Math.atan(Math.hypot(dzdx,dzdy))*180/Math.PI);
  }
  local.sort((a,b)=>a-b);
  const lv=[]; for(let y=cys-1;y<=cys+1;y++)for(let x=cxs-1;x<=cxs+1;x++){const v=cells[y][x]; if(Number.isFinite(v)) lv.push(v);} lv.sort((a,b)=>a-b);
  const lq=p=>lv[Math.min(lv.length-1,Math.floor(p*(lv.length-1)))];
  return {localSlope:local[Math.floor(.5*local.length)]||0, localRelief:(lq(.9)-lq(.1))||0};
}
(async()=>{
  const out=[];
  for(const s of SITES){
    try{
      const t=await terrain(s), c=await climate(s), sun=solar(s.lat);
      const dRelief=Math.abs(t.localRelief-800)/400, dSlope=Math.abs(t.localSlope-4)/3;
      const dTerrain=0.5*(dRelief+dSlope);
      const dThermal=Math.abs(c.seasonal-45)/12;
      const dIllum=Math.abs(sun-40)/12;
      const score=d=>1/(1+d);
      const aridity=Math.max(0,Math.min(1,1-(c.precip/800)));
      const similarity=0.45*score(dTerrain)+0.15*score(dThermal)+0.15*score(dIllum)+0.25*aridity;
      out.push({...s,similarity:+similarity.toFixed(2),localRelief:+t.localRelief.toFixed(0),localSlope:+t.localSlope.toFixed(2),seasonalAmp:c.seasonal,precip:c.precip,note:'similarity computed; attention not available this run, so no survey gap'});
      console.log(s.id, similarity.toFixed(2));
    }catch(e){ console.log(s.id,'FAIL',e.message); }
    await sleep(500);
  }
  const p=path.join(__dirname,'..','assets','data','roamer_data.json');
  const d=JSON.parse(fs.readFileSync(p,'utf8'));
  d.global_screening=out;
  fs.writeFileSync(p,JSON.stringify(d,null,1));
  console.log('wrote', out.length);
})();
