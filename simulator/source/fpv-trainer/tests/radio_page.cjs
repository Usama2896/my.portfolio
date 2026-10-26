const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const html = fs.readFileSync(path.join(__dirname, '../data/radio-test.html'), 'utf8');
const code = html.match(/<script>([\s\S]*?)<\/script>/)[1];
function element() { return { textContent:'', value:'', children:[], style:{}, handlers:{}, append(...nodes){this.children.push(...nodes);}, replaceChildren(...nodes){this.children=[...nodes];}, addEventListener(name,fn){this.handlers[name]=fn;}, focus(){},select(){} }; }
const elements = Object.fromEntries(['activate','reset','copy','status','device','axes','buttons','report'].map(id=>[id,element()]));
const pad = {index:0,id:'Simulated RadioMaster TX16',mapping:'',connected:true,axes:[0,0,0,-1],buttons:[{value:0,pressed:false}]};
let frame, copied='';
const context = vm.createContext({document:{getElementById:id=>elements[id],createElement:element,execCommand:()=>true},window:{isSecureContext:true,focus(){}},navigator:{userAgent:'test browser',getGamepads:()=>[pad],clipboard:{writeText:async text=>{copied=text;}}},requestAnimationFrame:fn=>{frame=fn;},console});
vm.runInContext(code,context);
(async()=>{
 elements.activate.handlers.click(); frame();
 assert.match(elements.status.textContent,/CONNECTED/);
 assert.equal(elements.axes.children.length,4);
 assert.equal(JSON.parse(elements.report.value).device.axes[3].raw,-1);
 pad.axes[3]=1; frame();
 const report=JSON.parse(elements.report.value);
 assert.equal(report.device.axes[3].min,-1); assert.equal(report.device.axes[3].max,1);
 await elements.copy.handlers.click(); assert.equal(copied,elements.report.value);
 context.navigator.getGamepads=undefined;elements.activate.handlers.click();assert.match(elements.status.textContent,/unavailable/);
 console.log('PASS: 7 offline radio-page checks — device, axis display, range, report, clipboard and unsupported browser');
})().catch(error=>{console.error(error);process.exitCode=1;});
