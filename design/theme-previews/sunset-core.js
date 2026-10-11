/* Deterministic atmosphere rules, shared by the preview and its checks. */
(function(root){
 'use strict';
 const phases={
  dawn:{label:'First light',bg:'#f6e8e3',side:'#eddbd6',surface:'#fff4ec',surface2:'#e5cdd0',ink:'#49333d',muted:'#775862',accent:'#994e54',secondary:'#62618a',sky:['#c3abc9','#efb9aa','#ffe1ae']},
  day:{label:'Daylight',bg:'#f7eee2',side:'#ece0cf',surface:'#fff9ee',surface2:'#e7d7bf',ink:'#493b32',muted:'#74634f',accent:'#905335',secondary:'#546856',sky:['#a9c9cc','#d6dfc5','#ffe6ad']},
  golden:{label:'Golden hour',bg:'#f6e7dc',side:'#efdbce',surface:'#fff3e9',surface2:'#e5cbbb',ink:'#4c3338',muted:'#76565c',accent:'#9d4d45',secondary:'#626293',sky:['#edab82','#f2d19e','#dfad94']},
  dusk:{label:'Blue hour',bg:'#2b293e',side:'#242135',surface:'#373149',surface2:'#494057',ink:'#f7e9e3',muted:'#c4b4c6',accent:'#edb19b',secondary:'#c2b7e3',sky:['#484b78','#a87c9c','#efb399']},
  night:{label:'Moonlit hours',bg:'#211e31',side:'#1b1929',surface:'#2c283e',surface2:'#3e354b',ink:'#f3e8e6',muted:'#bdb0c8',accent:'#eab99f',secondary:'#bdb6eb',sky:['#232740','#43466d','#81738f']}
 };
 const seasons={spring:{label:'Spring',hills:['#b6b68f','#8b9b83','#666d79']},summer:{label:'Summer',hills:['#ca9570','#a27573','#716582']},monsoon:{label:'Monsoon',hills:['#93a6a0','#668786','#4e6676']},autumn:{label:'Autumn',hills:['#bd805c','#985f60','#665475']},winter:{label:'Winter',hills:['#d5c8c5','#a8a3b5','#7d829e']}};
 const weatherNames={clear:'Clear sky',clouds:'Cloudy',rain:'Rain',fog:'Mist',snow:'Snow',storm:'Rainstorm'};
 function blend(a,b,amount){return '#'+[1,3,5].map(i=>Math.round(parseInt(a.slice(i,i+2),16)*(1-amount)+parseInt(b.slice(i,i+2),16)*amount).toString(16).padStart(2,'0')).join('');}
 function palette(phase,season,weather){
  const base=phases[phase],dark=phase==='night'||phase==='dusk';
  const wash={spring:'#e2e8d7',summer:'#ffe7bd',monsoon:'#b8c9c5',autumn:'#efc2a6',winter:'#d8deef'}[season];
  const tone=weather==='storm'?'#656879':weather==='rain'||weather==='clouds'?'#aeb8c3':weather==='fog'||weather==='snow'?'#d2d5df':null;
  return {...base,bg:blend(base.bg,wash,dark?.045:.24),side:blend(base.side,wash,dark?.04:.28),surface:blend(base.surface,wash,dark?.04:.18),surface2:blend(base.surface2,wash,dark?.07:.26),sky:base.sky.map(c=>tone?blend(c,tone,dark?.18:.4):blend(c,wash,.09))};
 }
 function weatherKind(code){
  if(code===0||code===1)return 'clear';
  if(code===2||code===3)return 'clouds';
  if(code===45||code===48)return 'fog';
  if([71,73,75,77,85,86].includes(code))return 'snow';
  if([95,96,99].includes(code))return 'storm';
  if([51,53,55,56,57,61,63,65,66,67,80,81,82].includes(code))return 'rain';
  return null;
 }
 function calendarSeason(month,profile='north'){
  if(profile==='monsoon'){if(month>=6&&month<=9)return 'monsoon';if(month>=10&&month<=11)return 'autumn';if(month===12||month===1)return 'winter';return month<=3?'spring':'summer';}
  if(profile==='south')month=((month+5)%12)+1;
  return month>=3&&month<=5?'spring':month>=6&&month<=8?'summer':month>=9&&month<=11?'autumn':'winter';
 }
 function phaseAt(hour,sunrise=6,sunset=18){
  if(hour<sunrise-1||hour>=sunset+1.25)return 'night';
  if(hour<sunrise+1)return 'dawn';
  if(hour<sunset-1.5)return 'day';
  if(hour<sunset+.25)return 'golden';
  return 'dusk';
 }
 function clockParts(date=new Date(),timezone){
  let parts;
  try{parts=new Intl.DateTimeFormat('en-CA',{timeZone:timezone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(date);}catch{return clockParts(date);}
  const p=Object.fromEntries(parts.map(x=>[x.type,x.value]));
  return {hour:Number(p.hour)+Number(p.minute)/60,month:Number(p.month),day:`${p.year}-${p.month}-${p.day}`,label:`${p.hour}:${p.minute}`};
 }
 function solarHours(value,day){if(typeof value!=='string'||!value.startsWith(day+'T'))return null;const m=value.match(/T(\d{2}):(\d{2})/);return m?+m[1]+(+m[2]/60):null;}
 function usableWeather(value,location,now=Date.now()){
  return !!(value&&location&&value.locationKey===`${location.latitude},${location.longitude}`&&Number.isFinite(value.fetchedAt)&&now>=value.fetchedAt&&now-value.fetchedAt<2*60*60*1000&&Number.isFinite(value.observedAt)&&now>=value.observedAt-15*60000&&now-value.observedAt<2*60*60*1000&&weatherKind(value.code)&&Number.isFinite(value.temperature));
 }
 function parseWeather(data,location,now=Date.now()){
  const current=data?.current;
  if(!current||!weatherKind(current.weather_code)||!Number.isFinite(current.temperature_2m)||!Number.isFinite(current.time))throw new Error('Weather response is incomplete.');
  const offset=Number(data.utc_offset_seconds)||0;
  const solar=(v)=>Number.isFinite(v)?new Date((v+offset)*1000).toISOString().slice(0,16):null;
  const result={locationKey:`${location.latitude},${location.longitude}`,code:current.weather_code,temperature:current.temperature_2m,isDay:current.is_day,observedAt:current.time*1000,fetchedAt:now,timezone:data.timezone,sunrise:solar(data.daily?.sunrise?.[0]),sunset:solar(data.daily?.sunset?.[0])};
  if(!usableWeather(result,location,now))throw new Error('Weather data is out of date.');
  return result;
 }
 const api={phases,seasons,weatherNames,palette,weatherKind,calendarSeason,phaseAt,clockParts,solarHours,usableWeather,parseWeather};
 root.SunsetAtmosphere=api;if(typeof module!=='undefined')module.exports=api;
})(typeof window!=='undefined'?window:globalThis);
