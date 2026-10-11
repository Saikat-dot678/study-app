const {test}=require('node:test');
const assert=require('node:assert/strict');
const A=require('./sunset-core.js');
test('day phases cross midnight and follow local sunrise/sunset',()=>{
 assert.deepEqual([0,5.5,12,17,18.5,23.99].map(h=>A.phaseAt(h)),['night','dawn','day','golden','dusk','night']);
 assert.equal(A.phaseAt(18,4.5,21),'day');assert.equal(A.phaseAt(20,4.5,21),'golden');
});
test('calendar supports both hemispheres and the monsoon profile',()=>{
 assert.equal(A.calendarSeason(1,'north'),'winter');assert.equal(A.calendarSeason(1,'south'),'summer');
 assert.equal(A.calendarSeason(7,'south'),'winter');assert.equal(A.calendarSeason(7,'monsoon'),'monsoon');
 assert.equal(A.calendarSeason(9,'monsoon'),'monsoon');assert.equal(A.calendarSeason(10,'monsoon'),'autumn');
});
test('city timezone handles date boundaries and midnight without hour 24',()=>{
 const date=new Date('2026-01-01T18:30:00Z');
 assert.deepEqual(A.clockParts(date,'Asia/Kolkata'),{hour:0,month:1,day:'2026-01-02',label:'00:00'});
 assert.equal(A.clockParts(date,'America/New_York').hour,13.5);
 assert.equal(A.solarHours('2026-01-01T06:12','2026-01-02'),null);
});
test('WMO codes classify frozen, rainy, and unknown conditions',()=>{
 assert.equal(A.weatherKind(0),'clear');assert.equal(A.weatherKind(3),'clouds');assert.equal(A.weatherKind(48),'fog');
 assert.equal(A.weatherKind(67),'rain');assert.equal(A.weatherKind(86),'snow');assert.equal(A.weatherKind(99),'storm');
 assert.equal(A.weatherKind(null),null);assert.equal(A.weatherKind(123),null);
});
const location={latitude:22.57,longitude:88.36}, now=Date.parse('2026-01-01T07:00:00Z');
const response={current:{weather_code:61,temperature_2m:22,time:now/1000-900,is_day:1},timezone:'Asia/Kolkata',utc_offset_seconds:19800,daily:{sunrise:[Date.parse('2026-01-01T00:42:00Z')/1000],sunset:[Date.parse('2026-01-01T12:00:00Z')/1000]}};
test('API timestamps retain UTC observation age and local solar clock',()=>{
 const data=A.parseWeather(response,location,now);assert.equal(data.sunrise,'2026-01-01T06:12');assert.equal(data.sunset,'2026-01-01T17:30');assert.equal(A.usableWeather(data,location,now),true);
 assert.equal(A.usableWeather(data,location,now+3*3600000),false);
 assert.equal(A.usableWeather(data,{latitude:0,longitude:0},now),false);
});
test('malformed, stale and future responses do not become live weather',()=>{
 assert.throws(()=>A.parseWeather({},location,now));assert.throws(()=>A.parseWeather({...response,current:{...response.current,time:now/1000-10800}},location,now));
 assert.throws(()=>A.parseWeather({...response,current:{...response.current,time:now/1000+7200}},location,now));
 assert.equal(A.usableWeather({fetchedAt:now},location,now),false);
});
test('all atmosphere combinations preserve readable body and button text',()=>{
 const light=hex=>[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((s,v,i)=>s+v*[.2126,.7152,.0722][i],0);
 const contrast=(a,b)=>{a=light(a);b=light(b);return (Math.max(a,b)+.05)/(Math.min(a,b)+.05);};
 for(const phase of Object.keys(A.phases))for(const season of Object.keys(A.seasons))for(const weather of Object.keys(A.weatherNames)){
  const p=A.palette(phase,season,weather),label=`${phase}/${season}/${weather}`;
  assert.ok(contrast(p.ink,p.bg)>=4.5,label+' body');assert.ok(contrast(p.muted,p.bg)>=4.5,label+' muted');
  assert.ok(contrast(p.accent,phase==='night'||phase==='dusk'?'#302536':'#fff8ee')>=4.5,label+' button');
 }
});
