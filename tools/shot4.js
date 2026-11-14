const { chromium } = require('/home/logic/node_modules/playwright');
(async()=>{
  const browser = await chromium.launch({args:['--no-sandbox']});
  const ctx = await browser.newContext({viewport:{width:1440,height:1000}});
  const page = await ctx.newPage();
  await page.goto('http://127.0.0.1:8099/', {waitUntil:'networkidle', timeout:60000});
  await page.waitForTimeout(6000);
  await page.screenshot({path:'/tmp/v2_find.png'});
  // search test
  await page.mouse.click(700, 145); await page.waitForTimeout(600); await page.keyboard.type('Lo', {delay:80}); await page.waitForTimeout(1200);
  await page.screenshot({path:'/tmp/v2_search.png'});
  await page.goto('http://127.0.0.1:8099/', {waitUntil:'networkidle', timeout:60000}); await page.waitForTimeout(5000);
  await page.mouse.click(720, 740); await page.waitForTimeout(2500); await page.screenshot({path:'/tmp/v2_record.png'});
  await page.mouse.wheel(0, 700); await page.waitForTimeout(1000); await page.screenshot({path:'/tmp/v2_record2.png'});
  await page.mouse.wheel(0, 700); await page.waitForTimeout(1000); await page.screenshot({path:'/tmp/v2_record3.png'});
  await page.goto('http://127.0.0.1:8099/', {waitUntil:'networkidle', timeout:60000}); await page.waitForTimeout(5000);
  await page.mouse.click(720, 952); await page.waitForTimeout(2500); await page.screenshot({path:'/tmp/v2_gap.png'});
  await page.mouse.wheel(0, 500); await page.waitForTimeout(1000); await page.screenshot({path:'/tmp/v2_gap2.png'});
  await page.goto('http://127.0.0.1:8099/', {waitUntil:'networkidle', timeout:60000}); await page.waitForTimeout(5000);
  await page.mouse.click(1120, 952); await page.waitForTimeout(2500); await page.screenshot({path:'/tmp/v2_method.png'});
  await browser.close(); console.log('done');
})();
