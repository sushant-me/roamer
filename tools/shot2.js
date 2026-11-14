const { chromium } = require('/home/logic/node_modules/playwright');
(async()=>{
  const browser = await chromium.launch({args:['--no-sandbox']});
  const ctx = await browser.newContext({viewport:{width:1440,height:1000}});
  const page = await ctx.newPage();
  await page.goto('http://127.0.0.1:8099/', {waitUntil:'networkidle', timeout:60000});
  await page.waitForTimeout(6000);
  // click Kagbeni pin approx (map starts x=36,y=267, size 1372)
  await page.mouse.click(650, 858);
  await page.waitForTimeout(2500);
  await page.screenshot({path:'/tmp/shot_record.png'});
  // scroll record
  await page.mouse.wheel(0, 700); await page.waitForTimeout(1200); await page.screenshot({path:'/tmp/shot_record2.png'});
  await page.mouse.wheel(0, 700); await page.waitForTimeout(1200); await page.screenshot({path:'/tmp/shot_record3.png'});
  // reload -> gap tab
  await page.goto('http://127.0.0.1:8099/', {waitUntil:'networkidle', timeout:60000});
  await page.waitForTimeout(5000);
  await page.mouse.click(720, 955);
  await page.waitForTimeout(2500);
  await page.screenshot({path:'/tmp/shot_gap.png'});
  // mobile
  const m = await browser.newContext({viewport:{width:390,height:844}, deviceScaleFactor:2, isMobile:true});
  const mp = await m.newPage();
  await mp.goto('http://127.0.0.1:8099/', {waitUntil:'networkidle', timeout:60000});
  await mp.waitForTimeout(6000);
  await mp.screenshot({path:'/tmp/shot_mobile.png'});
  await browser.close(); console.log('done');
})();
