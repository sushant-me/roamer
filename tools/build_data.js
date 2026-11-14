const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');
const { mosaic, lon2tile, lat2tile, tile2lon, tile2lat, metersPerPixel } = require('./lib_geo');

const OUT = path.join(__dirname, '..', 'assets', 'data');
const MAPDIR = path.join(__dirname, '..', 'assets', 'map');
fs.mkdirSync(OUT, { recursive: true }); fs.mkdirSync(MAPDIR, { recursive: true });

const SITES = [
  { id:'kagbeni', name:'Kagbeni / Lower Mustang', country:'Nepal', lat:28.8167, lon:83.7833, alt_m:2800, role:'candidate',
    blurb:'The 2019 MAU-Nepal 001 site. Road-reachable since 2024; the Kali Gandaki valley floor is the flattest ground for kilometres.',
    operability:0.9, access:'Road (Jomsom–Kagbeni blacktopped 2024), ACAP permit, lodges in Kagbeni.' },
  { id:'lo_manthang', name:'Lo Manthang', country:'Nepal', lat:29.1833, lon:83.9667, alt_m:3840, role:'candidate',
    blurb:'High, dry, windswept Tibetan plateau beyond the Himalaya; restricted-area permit required.',
    operability:0.45, access:'Restricted-area permit; road from Jomsom seasonal; 4–6 h drive.' },
  { id:'phoksundo', name:'Shey Phoksundo', country:'Nepal', lat:29.15, lon:82.90, alt_m:3600, role:'candidate',
    blurb:'Remote Dolpo basin around Nepal’s deepest lake; national-park permit, no road to the lake.',
    operability:0.3, access:'Shey Phoksundo National Park permit; trek 1–2 days from the road head.' },
  { id:'khumbu', name:'Khumbu (Pangboche)', country:'Nepal', lat:27.85, lon:86.75, alt_m:3900, role:'positive_control',
    blurb:'Published subcontinental analog (Frontiers 2025 review); high-altitude, glacier-fed, well studied.',
    operability:0.8, access:'Lukla flight + 2 days trek; Sagarmatha National Park permit.' },
  { id:'atacama', name:'Atacama (Yungay)', country:'Chile', lat:-24.10, lon:-70.00, alt_m:1200, role:'positive_control',
    blurb:'The canonical Mars analog: hyper-arid, low organic load, decades of analog research.',
    operability:0.6, access:'Road access from Antofagasta; research permits for protected areas.' },
  { id:'pokhara', name:'Pokhara (mid-hill)', country:'Nepal', lat:28.21, lon:83.99, alt_m:800, role:'negative_control',
    blurb:'Wet, vegetated mid-hill control. Should fail the desert/thermal requirements — if it passes, the method is broken.',
    operability:0.95, access:'Road, city services.' },
];

const TARGET = {
  id:'mars_midlat', name:'Mars mid-latitude base (Jezero / NE Syrtis)',
  terrain:{ relief_m:{mean:800, sd:400}, slope_med_deg:{mean:4, sd:3} },
  thermal:{ seasonal_amp_k:{mean:45, sd:12} },
  illumination:{ noon_elev_deg:{mean:40, sd:12} },
  source:'Target bands from published Mars mid-latitude statistics (MOLA topography; THEMIS/Diviner thermal summaries; PDS). Values are documented ranges, not a single mission measurement.'
};

// ---------- terrain ----------
async function siteTerrain(site){
  const z=12, halfKm=6;
  const dLat=halfKm/111, dLon=halfKm/(111*Math.cos(site.lat*Math.PI/180));
  const m=await mosaic(z, site.lon-dLon, site.lon+dLon, site.lat-dLat, site.lat+dLat);
  const res=metersPerPixel(site.lat,z);
  const cellPx=Math.max(2, Math.round(500/res));
  const NX=Math.floor(m.W/cellPx), NY=Math.floor(m.H/cellPx);
  const cells=Array.from({length:NY},()=>new Float64Array(NX));
  for(let cy=0;cy<NY;cy++) for(let cx=0;cx<NX;cx++){
    let s=0,n=0;
    for(let py=0;py<cellPx;py++) for(let px=0;px<cellPx;px++){
      const v=m.grid[(cy*cellPx+py)*m.W+(cx*cellPx+px)];
      if(Number.isFinite(v)){s+=v;n++;}
    }
    cells[cy][cx]=n?s/n:NaN;
  }
  const vals=[]; for(const r of cells) for(const v of r) if(Number.isFinite(v)) vals.push(v);
  vals.sort((a,b)=>a-b); const q=p=>vals[Math.min(vals.length-1,Math.floor(p*(vals.length-1)))];
  const relief=+((q(.95)-q(.05)).toFixed(0));
  const slopes=[];
  for(let y=1;y<NY-1;y++) for(let x=1;x<NX-1;x++){
    const a=cells[y-1][x-1],b=cells[y-1][x],c=cells[y-1][x+1];
    const d=cells[y][x-1],e=cells[y][x+1],f=cells[y+1][x-1],g=cells[y+1][x],h=cells[y+1][x+1];
    if([a,b,c,d,e,f,g,h].some(v=>!Number.isFinite(v))) continue;
    const dzdx=((c+2*e+h)-(a+2*d+f))/(8*500), dzdy=((f+2*g+h)-(a+2*b+c))/(8*500);
    slopes.push(Math.atan(Math.hypot(dzdx,dzdy))*180/Math.PI);
  }
  slopes.sort((a,b)=>a-b);
  const med=+(slopes[Math.floor(.5*slopes.length)]||0).toFixed(2);
  const iqr=+(((slopes[Math.floor(.75*slopes.length)]||0)-(slopes[Math.floor(.25*slopes.length)]||0))).toFixed(2);
  // roughness: mean abs residual from local 3x3 mean
  let rough=[];
  for(let y=1;y<NY-1;y++) for(let x=1;x<NX-1;x++){
    let s=0,n=0;
    for(let dy=-1;dy<=1;dy++) for(let dx=-1;dx<=1;dx++){ const v=cells[y+dy][x+dx]; if(Number.isFinite(v)){s+=v;n++;} }
    const v=cells[y][x]; if(Number.isFinite(v)&&n===9) rough.push(Math.abs(v-s/9));
  }
  // variogram slope (log gamma vs log lag)
  const pts=[]; const gamma=[];
  for(let lag=1;lag<=8;lag++){
    let sum=0,n=0;
    for(let y=0;y<NY;y+=2) for(let x=0;x<NX-lag;x+=2){ const v=cells[y][x],w=cells[y][x+lag]; if(Number.isFinite(v)&&Number.isFinite(w)){sum+=0.5*(v-w)**2;n++;} }
    if(n) gamma.push([lag, sum/n]);
  }
  let vario=0;
  if(gamma.length>=3){ const xs=gamma.map(g=>Math.log(g[0])), ys=gamma.map(g=>Math.log(Math.max(1,g[1]))); const mx=xs.reduce((a,b)=>a+b)/xs.length, my=ys.reduce((a,b)=>a+b)/ys.length; let num=0,den=0; xs.forEach((x,i)=>{num+=(x-mx)*(ys[i]-my); den+=(x-mx)**2;}); vario=+(num/den).toFixed(2); }
  // local site slope: central ~3 km (7x7 cells at 500 m)
  const cxs=Math.floor(NX/2), cys=Math.floor(NY/2);
  const loc=[];
  for(let y=cys-1;y<=cys+1;y++) for(let x=cxs-1;x<=cxs+1;x++){
    if(y<1||x<1||y>=NY-1||x>=NX-1) continue;
    const a=cells[y-1][x-1],b=cells[y-1][x],c=cells[y-1][x+1];
    const d=cells[y][x-1],e=cells[y][x+1],f=cells[y+1][x-1],g=cells[y+1][x],h=cells[y+1][x+1];
    if([a,b,c,d,e,f,g,h].some(v=>!Number.isFinite(v))) continue;
    const dzdx=((c+2*e+h)-(a+2*d+f))/(8*500), dzdy=((f+2*g+h)-(a+2*b+c))/(8*500);
    loc.push(Math.atan(Math.hypot(dzdx,dzdy))*180/Math.PI);
  }
  loc.sort((a,b)=>a-b);
  const localSlope=+(loc[Math.floor(.5*loc.length)]||med).toFixed(2);
  const locVals=[];
  for(let y=cys-1;y<=cys+1;y++) for(let x=cxs-1;x<=cxs+1;x++){ const v=cells[y][x]; if(Number.isFinite(v)) locVals.push(v); }
  locVals.sort((a,b)=>a-b); const lq=p=>locVals[Math.min(locVals.length-1,Math.floor(p*(locVals.length-1)))];
  const localRelief=+((lq(.9)-lq(.1))||0).toFixed(0);
  return { relief_m:relief, local_relief_m:localRelief, slope_med_deg:med, local_slope_med_deg:localSlope, slope_iqr_deg:iqr, rough_m:+ (rough.reduce((a,b)=>a+b,0)/Math.max(1,rough.length)).toFixed(1), vario_slope:vario,
    cells:NX+'x'+NY, cell_size_m:500, window_km:halfKm*2, mosaic_px:m.W+'x'+m.H, native_res_m:+res.toFixed(1) };
}

// ---------- climate (Open-Meteo archive, 2015–2024, cached + retried) ----------
const CACHE = path.join(__dirname, 'cache'); fs.mkdirSync(CACHE, { recursive: true });
async function climate(site){
  const cf = path.join(CACHE, 'climate_'+site.id+'.json');
  if (fs.existsSync(cf)) return JSON.parse(fs.readFileSync(cf,'utf8'));
  const url=`https://archive-api.open-meteo.com/v1/archive?latitude=${site.lat}&longitude=${site.lon}&start_date=2015-01-01&end_date=2024-12-31&daily=precipitation_sum,temperature_2m_max,temperature_2m_min,shortwave_radiation_sum&timezone=auto`;
  let j=null;
  for(let attempt=0; attempt<6; attempt++){
    try{
      const r=await fetch(url);
      if(r.status===429){ await new Promise(res=>setTimeout(res, 15000+attempt*5000)); continue; }
      if(!r.ok) throw new Error('open-meteo '+r.status);
      j=await r.json(); break;
    }catch(e){ await new Promise(res=>setTimeout(res, 5000+attempt*3000)); }
  }
  if(!j) throw new Error('climate unavailable');
  const d=j.daily; const sum=a=>a.reduce((x,y)=>x+y,0), mean=a=>sum(a)/a.length;
  const precipAnnual=sum(d.precipitation_sum)/10;
  const diurnal=mean(d.temperature_2m_max.map((v,i)=>(v-d.temperature_2m_min[i])/2));
  const months=Array.from({length:12},()=>[]);
  d.time.forEach((t,i)=>{ const m=+t.slice(5,7)-1; months[m].push((d.temperature_2m_max[i]+d.temperature_2m_min[i])/2); });
  const monthly=months.map(a=>mean(a));
  const seasonal=+((Math.max(...monthly)-Math.min(...monthly))/2).toFixed(1);
  const solar=+(sum(d.shortwave_radiation_sum)/10/1000).toFixed(2);
  const out={ precip_annual_mm:+precipAnnual.toFixed(0), seasonal_amp_k:seasonal, diurnal_amp_k:+diurnal.toFixed(1),
    solar_kwh_m2_day:solar, source:'Open-Meteo ERA5 archive 2015–2024 at the site point (air temperature; shortwave radiation). Skin temperature is not computed (MODIS LST needs Earthdata login).' };
  fs.writeFileSync(cf, JSON.stringify(out,null,1));
  return out;
}

// ---------- literature ----------
async function openalex(q){
  const url='https://api.openalex.org/works?search='+encodeURIComponent(q)+'&per-page=1';
  const r=await fetch(url); if(!r.ok) throw new Error('OpenAlex '+r.status);
  const j=await r.json(); return j.meta.count;
}

// ---------- solar ----------
function solar(lat){
  const rad=Math.PI/180;
  function decl(day){ return 23.45*Math.sin(2*Math.PI*(284+day)/365); }
  function noonElev(day){ return 90-Math.abs(lat-decl(day)); }
  function dayLen(day){ const d=decl(day)*rad, phi=lat*rad; const cosH=-Math.tan(phi)*Math.tan(d); if(cosH>=1) return 0; if(cosH<=-1) return 24; return 2*Math.acos(cosH)/rad/15; }
  const dec21=noonElev(355), jun21=noonElev(172), avgDay=([15,45,74,105,135,166,196,227,258,288,319,349].map(dayLen).reduce((a,b)=>a+b,0))/12;
  return { noon_elev_dec21_deg:+dec21.toFixed(1), noon_elev_jun21_deg:+jun21.toFixed(1), noon_elev_min_deg:+Math.min(dec21,jun21).toFixed(1),
    daylength_dec21_h:+dayLen(355).toFixed(1), daylength_jun21_h:+dayLen(172).toFixed(1), daylight_frac:+(avgDay/24).toFixed(3) };
}

// ---------- scoring ----------
function scoreSite(site, terrain, clim, solarF, lit){
  const t=TARGET;
  const dRelief=Math.abs(terrain.local_relief_m-t.terrain.relief_m.mean)/t.terrain.relief_m.sd;
  const dSlope=Math.abs(terrain.local_slope_med_deg-t.terrain.slope_med_deg.mean)/t.terrain.slope_med_deg.sd;
  const dTerrain=+(0.5*(dRelief+dSlope)).toFixed(2);
  const dThermal=+(Math.abs(clim.seasonal_amp_k-t.thermal.seasonal_amp_k.mean)/t.thermal.seasonal_amp_k.sd).toFixed(2);
  const dIllum=+(Math.abs(solarF.noon_elev_min_deg-t.illumination.noon_elev_deg.mean)/t.illumination.noon_elev_deg.sd).toFixed(2);
  const score=d=>+(1/(1+d)).toFixed(2);
  const terrainScore=score(dTerrain), thermalScore=score(dThermal), illumScore=score(dIllum);
  const aridityScore=+Math.max(0,Math.min(1,1-(clim.precip_annual_mm/800))).toFixed(2);
  const req={
    trafficable_slopes:{ pass: terrain.local_slope_med_deg<=10, value:terrain.local_slope_med_deg, unit:'° local slope (3 km)', threshold:'≤10°' },
    terrain_relief:{ pass: terrain.local_relief_m>=20 && terrain.local_relief_m<=1500, value:terrain.local_relief_m, unit:'m P90–P10 (1.5 km site pad)', threshold:'150–1,500 m' },
    sunlight:{ pass: solarF.noon_elev_min_deg>=20, value:solarF.noon_elev_min_deg, unit:'° noon elevation (worst solstice)', threshold:'≥20°' },
    aridity:{ pass: clim.precip_annual_mm<800, value:clim.precip_annual_mm, unit:'mm/yr precipitation', threshold:'<800 mm (semi-arid)' },
    access:{ pass: (site.operability??0)>=0.5, value:site.operability, unit:'operability 0–1', threshold:'≥0.5' },
  };
  const passes=Object.values(req).filter(r=>r.pass).length;
  const similarity=+(0.45*terrainScore+0.15*thermalScore+0.15*illumScore+0.25*aridityScore).toFixed(2);
  const attention=+(Math.min(1, Math.log10((lit||0)+1)/4)).toFixed(2);
  const gap=+(similarity*(1-attention)*(site.operability??0.5)).toFixed(2);
  return { d:{terrain:dTerrain, thermal:dThermal, illumination:dIllum}, scores:{terrain:terrainScore,thermal:thermalScore,illumination:illumScore,aridity:aridityScore, similarity},
    requirements:req, passes, requirements_total:5, attention, survey_gap:gap };
}

// ---------- hillshade map ----------
async function hillshade(){
  const z=7, lonMin=79.6, lonMax=89.4, latMin=25.6, latMax=31.4;
  const m=await mosaic(z, lonMin, lonMax, latMin, latMax);
  const W=m.W,H=m.H; const png=new PNG({width:W,height:H});
  const res=metersPerPixel(28,z);
  const sunAz=315*Math.PI/180, sunAlt=45*Math.PI/180;
  const ramp=[[8,20,44],[22,44,80],[55,80,110],[120,130,130],[190,175,145],[235,220,190]];
  function col(t){ t=Math.max(0,Math.min(1,t)); const x=t*(ramp.length-1); const i=Math.floor(x), f=x-i; const a=ramp[i], b=ramp[Math.min(ramp.length-1,i+1)]; return [a[0]+(b[0]-a[0])*f, a[1]+(b[1]-a[1])*f, a[2]+(b[2]-a[2])*f]; }
  const zs=[]; for(let i=0;i<W*H;i++) if(Number.isFinite(m.grid[i])) zs.push(m.grid[i]);
  zs.sort((a,b)=>a-b); const q=p=>zs[Math.min(zs.length-1,Math.floor(p*(zs.length-1)))];
  const lo=q(.02), hi=q(.98);
  for(let y=0;y<H;y++) for(let x=0;x<W;x++){
    const idx=y*W+x; const v=m.grid[idx];
    if(!Number.isFinite(v)){ png.data[idx*4]=8; png.data[idx*4+1]=14; png.data[idx*4+2]=30; png.data[idx*4+3]=255; continue; }
    const xm=Math.max(0,x-1), xp=Math.min(W-1,x+1), ym=Math.max(0,y-1), yp=Math.min(H-1,y+1);
    const dzdx=(m.grid[y*W+xp]-m.grid[y*W+xm])/(2*res), dzdy=(m.grid[yp*W+x]-m.grid[ym*W+x])/(2*res);
    const slope=Math.atan(Math.hypot(dzdx,dzdy)), aspect=Math.atan2(dzdy,-dzdx);
    const shade=Math.max(0, Math.cos(Math.PI/2-sunAlt)*Math.cos(slope)+Math.sin(Math.PI/2-sunAlt)*Math.sin(slope)*Math.cos(sunAz-aspect));
    const [r,g,b]=col((v-lo)/(hi-lo));
    const k=0.35+0.65*shade;
    png.data[idx*4]=Math.min(255,r*k); png.data[idx*4+1]=Math.min(255,g*k); png.data[idx*4+2]=Math.min(255,b*k); png.data[idx*4+3]=255;
  }
  fs.writeFileSync(path.join(MAPDIR,'hillshade.png'), PNG.sync.write(png));
  // pins
  const pins=SITES.map(s=>{ const px=(lon2tile(s.lon,z)-m.x0)*256; const py=(lat2tile(s.lat,z)-m.y0)*256; return {id:s.id, x:+(px/W).toFixed(4), y:+(py/H).toFixed(4)}; });
  return { image:'assets/map/hillshade.png', width:W, height:H, lonMin: tile2lon(m.x0,z), latMax: tile2lat(m.y0,z),
    lonMax: tile2lon(m.x0+W/256,z), latMin: tile2lat(m.y0+H/256,z), pins };
}

(async()=>{
  console.log('terrain + climate + literature...');
  const out={sites:[], meta:{generated:new Date().toISOString(), method:'Terrarium elevation tiles (z12) → 500 m block-average → slope/roughness/variogram; NASA POWER climatology; OpenAlex literature counts; solar geometry (NOAA-style).'}};
  for(const s of SITES){
    process.stdout.write('  '+s.name+' ... ');
    const terrain=await siteTerrain(s);
    let clim; try{ clim=await climate(s); }catch(e){ console.log('climate fail', e.message); clim={}; }
    let lit=0; try{ lit=await openalex(s.name.split('(')[0].trim()); }catch(e){}
    const solarF=solar(s.lat);
    const sc=scoreSite(s, terrain, clim, solarF, lit);
    out.sites.push({...s, features:{terrain, thermal:{seasonal_amp_k:clim.seasonal_amp_k, diurnal_amp_k:clim.diurnal_amp_k}, illumination:solarF, water:{precip_annual_mm:clim.precip_annual_mm}},
      climate:clim, literature:{count:lit, query:s.name}, ...sc});
    console.log('ok relief',terrain.relief_m,'slope',terrain.slope_med_deg,'passes',sc.passes,'sim',sc.scores.similarity,'gap',sc.survey_gap);
  }
  console.log('hillshade...');
  const map=await hillshade();
  out.target=TARGET; out.map=map;
  fs.writeFileSync(path.join(OUT,'roamer_data.json'), JSON.stringify(out,null,1));
  console.log('wrote', path.join(OUT,'roamer_data.json'));
})();
