const { chromium } = require('/home/logic/node_modules/playwright');
(async()=>{
  const browser = await chromium.launch({args:['--no-sandbox']});
  const ctx = await browser.newContext({viewport:{width:1440,height:1000}, deviceScaleFactor:1});
  const page = await ctx.newPage();
  await page.goto('http://127.0.0.1:8099/', {waitUntil:'networkidle', timeout:60000});
  await page.waitForTimeout(6000);
  await page.screenshot({path:'/tmp/shot_find.png'});
  // click first site card (text Kagbeni)
  const card = page.getByText('Kagbeni / Lower Mustang').first();
  if (await card.count()) { await card.click(); await page.waitForTimeout(3000); await page.screenshot({path:'/tmp/shot_record.png'}); }
  // back then Gap tab
  await page.goBack(); await page.waitForTimeout(2500);
  const gap = page.getByText('SURVEY GAP').last();
  if (await gap.count()) { await gap.click(); await page.waitForTimeout(2500); await page.screenshot({path:'/tmp/shot_gap.png'}); }
  await browser.close();
  console.log('shots done');
})();
