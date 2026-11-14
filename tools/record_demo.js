const { chromium } = require('/home/logic/node_modules/playwright');
(async()=>{
  const browser = await chromium.launch({args:['--no-sandbox']});
  const ctx = await browser.newContext({viewport:{width:1440,height:900}, recordVideo:{dir:'/tmp/vid', size:{width:1440,height:900}}});
  const page = await ctx.newPage();
  await page.goto('http://127.0.0.1:8099/', {waitUntil:'networkidle', timeout:60000});
  await page.waitForTimeout(5000);
  await page.waitForTimeout(2500);                       // hold FIND
  await page.mouse.click(700,145); await page.waitForTimeout(500);
  await page.keyboard.type('Kagbeni', {delay:150}); await page.waitForTimeout(1800);
  await page.mouse.click(720,740); await page.waitForTimeout(2500);   // record open
  await page.mouse.wheel(0,700); await page.waitForTimeout(2000);
  await page.mouse.wheel(0,700); await page.waitForTimeout(2000);
  await page.mouse.wheel(0,700); await page.waitForTimeout(2000);
  await page.mouse.wheel(0,700); await page.waitForTimeout(2000);
  await page.mouse.click(28,28); await page.waitForTimeout(2000);
  await page.mouse.click(720,852); await page.waitForTimeout(2600);   // gap
  await page.mouse.wheel(0,400); await page.waitForTimeout(2000);
  await page.mouse.click(720,620); await page.waitForTimeout(2200);   // record from gap
  await page.mouse.wheel(0,2500); await page.waitForTimeout(2000);
  await page.mouse.click(720,860); await page.waitForTimeout(3500);   // brief, hold
  await ctx.close(); await browser.close(); console.log('recorded');
})();
