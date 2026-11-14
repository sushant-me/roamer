const { PNG } = require('pngjs');

function lon2tile(lon, z){ return (lon + 180) / 360 * Math.pow(2, z); }
function lat2tile(lat, z){ const r = lat*Math.PI/180; return (1 - Math.log(Math.tan(r) + 1/Math.cos(r))/Math.PI)/2 * Math.pow(2, z); }
function tile2lon(x, z){ return x / Math.pow(2,z) * 360 - 180; }
function tile2lat(y, z){ const n = Math.PI - 2*Math.PI*y/Math.pow(2,z); return 180/Math.PI*Math.atan(0.5*(Math.exp(n)-Math.exp(-n))); }
function metersPerPixel(lat, z){ return 156543.03392 * Math.cos(lat*Math.PI/180) / Math.pow(2,z); }

async function fetchTile(z, x, y){
  const url = `https://s3.amazonaws.com/elevation-tiles-prod/terrarium/${z}/${x}/${y}.png`;
  for (let attempt=0; attempt<3; attempt++){
    try {
      const r = await fetch(url);
      if (!r.ok) throw new Error('http '+r.status);
      const buf = Buffer.from(await r.arrayBuffer());
      const png = PNG.sync.read(buf);
      const w = png.width, h = png.height, data = png.data;
      const elev = new Float32Array(w*h);
      for (let i=0;i<w*h;i++){
        const R=data[i*4], G=data[i*4+1], B=data[i*4+2];
        elev[i] = (R*256 + G + B/256) - 32768;
      }
      return {w,h,elev};
    } catch(e){ await new Promise(r=>setTimeout(r, 800*(attempt+1))); }
  }
  throw new Error('tile failed '+z+'/'+x+'/'+y);
}

// mosaic of tiles covering a lat/lon window at zoom z
async function mosaic(z, lonMin, lonMax, latMin, latMax){
  const x0=Math.floor(lon2tile(lonMin,z)), x1=Math.floor(lon2tile(lonMax,z));
  const y0=Math.floor(lat2tile(latMax,z)), y1=Math.floor(lat2tile(latMin,z));
  const cols=x1-x0+1, rows=y1-y0+1;
  const W=cols*256, H=rows*256;
  const grid=new Float32Array(W*H).fill(NaN);
  const jobs=[];
  for(let ty=0;ty<rows;ty++) for(let tx=0;tx<cols;tx++) jobs.push({tx,ty});
  let i=0;
  async function worker(){
    while(i<jobs.length){
      const j=jobs[i++];
      const t=await fetchTile(z, x0+j.tx, y0+j.ty);
      for(let py=0;py<256;py++) for(let px=0;px<256;px++)
        grid[(j.ty*256+py)*W + (j.tx*256+px)] = t.elev[py*256+px];
    }
  }
  await Promise.all(Array.from({length:8}, worker));
  return {grid, W, H, x0, y0, z, lonMin: tile2lon(x0,z), latMax: tile2lat(y0,z)};
}
module.exports = {lon2tile, lat2tile, tile2lon, tile2lat, metersPerPixel, fetchTile, mosaic};
