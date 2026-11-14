const { mosaic, metersPerPixel } = require('./lib_geo');
(async()=>{
  const lat=28.8167, lon=83.7833, z=12;
  const dLat = 14/111, dLon = 14/(111*Math.cos(lat*Math.PI/180));
  const m = await mosaic(z, lon-dLon, lon+dLon, lat-dLat, lat+dLat);
  console.log('mosaic', m.W, m.H, 'mpp', metersPerPixel(lat,z).toFixed(1));
  // block average to 500 m
  const res = metersPerPixel(lat,z); const cellPx = Math.max(2, Math.round(500/res));
  const NX = Math.floor(m.W/cellPx), NY = Math.floor(m.H/cellPx);
  const cells = Array.from({length:NY}, ()=>new Float64Array(NX));
  for(let cy=0;cy<NY;cy++) for(let cx=0;cx<NX;cx++){
    let s=0,n=0;
    for(let py=0;py<cellPx;py++) for(let px=0;px<cellPx;px++){
      const v=m.grid[(cy*cellPx+py)*m.W + (cx*cellPx+px)];
      if(Number.isFinite(v)){s+=v;n++;}
    }
    cells[cy][cx]= n? s/n : NaN;
  }
  const zs=[]; for(const row of cells) for(const v of row) if(Number.isFinite(v)) zs.push(v);
  zs.sort((a,b)=>a-b); const q=p=>zs[Math.min(zs.length-1,Math.floor(p*(zs.length-1)))];
  console.log('cells', NX+'x'+NY, 'elev p5/p50/p95', q(.05).toFixed(0), q(.5).toFixed(0), q(.95).toFixed(0), 'relief', (q(.95)-q(.05)).toFixed(0));
  // slope at 500m
  const slopes=[];
  for(let y=1;y<NY-1;y++) for(let x=1;x<NX-1;x++){
    const z00=cells[y-1][x-1],z01=cells[y-1][x],z02=cells[y-1][x+1];
    const z10=cells[y][x-1],z12=cells[y][x+1];
    const z20=cells[y+1][x-1],z21=cells[y+1][x],z22=cells[y+1][x+1];
    if([z00,z01,z02,z10,z12,z20,z21,z22].some(v=>!Number.isFinite(v))) continue;
    const dzdx=((z02+2*z12+z22)-(z00+2*z10+z20))/(8*500);
    const dzdy=((z20+2*z21+z22)-(z00+2*z01+z02))/(8*500);
    slopes.push(Math.atan(Math.hypot(dzdx,dzdy))*180/Math.PI);
  }
  slopes.sort((a,b)=>a-b);
  console.log('slope med', slopes[Math.floor(.5*slopes.length)].toFixed(2), 'iqr', (slopes[Math.floor(.75*slopes.length)]-slopes[Math.floor(.25*slopes.length)]).toFixed(2));
})();
