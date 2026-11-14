const { chromium } = require('/home/logic/node_modules/playwright');
(async()=>{
  const b = await chromium.launch({args:['--no-sandbox']});
  const p = await (await b.newContext({viewport:{width:1440,height:1000}})).newPage();
  await p.goto('http://127.0.0.1:8099/', {waitUntil:'networkidle', timeout:60000}); await p.waitForTimeout(5000);
  await p.mouse.click(720, 952); await p.waitForTimeout(2500); await p.screenshot({path:'/tmp/v3_gap.png'});
  await p.mouse.wheel(0, 500); await p.waitForTimeout(1000); await p.screenshot({path:'/tmp/v3_gap2.png'});
  await b.close(); console.log('ok');
})();
