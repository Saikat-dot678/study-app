(function(){
 'use strict';
 const A=window.SunsetAtmosphere, q=s=>document.querySelector(s);
 const key='study-living-sunset-v1';
 const read=(suffix,fallback)=>{try{return JSON.parse(localStorage.getItem(key+suffix))??fallback;}catch{return fallback;}};
 const write=(suffix,value)=>{try{localStorage.setItem(key+suffix,JSON.stringify(value));}catch{/* Session remains usable. */}};
 const saved=read(':settings',{});
 const validLocation=l=>l&&typeof l.name==='string'&&Number.isFinite(l.latitude)&&Math.abs(l.latitude)<=90&&Number.isFinite(l.longitude)&&Math.abs(l.longitude)<=180;
 const env={hour:null,season:'auto',weather:'auto',profile:['north','south','monsoon'].includes(saved.profile)?saved.profile:'north',location:validLocation(saved.location)?saved.location:null,enabled:saved.enabled===true,cache:read(':weather',null),busy:false,lastAttempt:0};
 let request=null,revision=0,results=[],signature='',statusMessage='',failed=false;
 const panel=document.createElement('section');panel.id='sunset-controls';panel.className='sunset-controls';panel.setAttribute('aria-label','Living Sunset controls');
 panel.innerHTML=`<div class="living-heading"><div><span class="living-kicker">SUNSET SCHOLAR / THE LIVING EDITION</span><h2>A desk in tune with your day.</h2></div><span class="living-status" id="living-status"></span></div>
  <div class="atmosphere-controls"><div class="day-control"><div class="control-label"><label for="sunset-hour">Time of day</label><output id="sunset-time" for="sunset-hour"></output><button id="sunset-now" type="button">Follow my clock</button></div><input id="sunset-hour" type="range" min="0" max="1439" step="1" aria-label="Preview time of day"><div class="day-labels"><span>Midnight</span><span>Dawn</span><span>Noon</span><span>Sunset</span><span>Night</span></div></div>
  <label class="select-control">Season<select id="sunset-season"><option value="auto">Follow the calendar</option><option value="spring">Spring · blossom</option><option value="summer">Summer · sun-washed</option><option value="monsoon">Monsoon · rain garden</option><option value="autumn">Autumn · terracotta</option><option value="winter">Winter · soft frost</option></select></label>
  <label class="select-control">Weather<select id="sunset-weather"><option value="auto">Use local weather</option><option value="clear">Preview · clear sky</option><option value="clouds">Preview · cloudy</option><option value="rain">Preview · rain</option><option value="fog">Preview · mist</option><option value="snow">Preview · snow</option><option value="storm">Preview · rainstorm</option></select></label></div>
  <details class="weather-settings"><summary>Local weather & season settings <span id="weather-summary">Optional · no API key</span></summary><div class="weather-settings-inner"><div><p>Use your city, or share your approximate location with Open-Meteo. Weather refreshes every 30 minutes. Your clock and calendar work offline.</p><form id="weather-city-form"><label class="sr-only" for="weather-city">City for weather</label><input id="weather-city" maxlength="80" placeholder="Search a city, e.g. Kolkata" autocomplete="off" required minlength="2"><button type="submit" id="weather-search">Find city</button><button type="button" id="weather-locate">Use my location</button></form><div id="weather-results" class="weather-results"></div><div class="weather-actions"><button id="weather-refresh" type="button">Refresh weather</button><button id="weather-disconnect" type="button">Turn weather off</button></div></div><label class="select-control">Season calendar<select id="sunset-profile"><option value="north">Northern hemisphere</option><option value="south">Southern hemisphere</option><option value="monsoon">India · includes monsoon</option></select><small>Calendar-based colors. Override the season whenever you like.</small></label></div></details>
  <div class="weather-foot"><p id="weather-status" role="status"></p><a href="https://open-meteo.com/" target="_blank" rel="noopener">Weather by Open-Meteo ↗</a></div>`;
 q('.review-caption').after(panel);
 q('#sunset-profile').value=env.profile;
 function persist(){write(':settings',{profile:env.profile,location:env.location,enabled:env.enabled});}
 function fresh(){return env.enabled&&A.usableWeather(env.cache,env.location);}
 function current(){
  const data=fresh()?env.cache:null;
  const clock=A.clockParts(new Date(),env.enabled?data?.timezone||env.location?.timezone:undefined);
  const hour=env.hour??clock.hour;
  const sunrise=A.solarHours(data?.sunrise,clock.day)??6, sunset=A.solarHours(data?.sunset,clock.day)??18;
  let phase=A.phaseAt(hour,sunrise,sunset);
  // Polar day/night may have no sunrise or sunset in the response.
  if(env.hour===null&&data&&(!data.sunrise||!data.sunset))phase=data.isDay===1?'day':'night';
  return {clock,hour,phase,season:env.season==='auto'?A.calendarSeason(clock.month,env.profile):env.season,weather:env.weather==='auto'?(data?A.weatherKind(data.code):'clear'):env.weather,data};
 }
 function addScene(){
  const portal=q('.sunset-portal');if(!portal||portal.querySelector('.living-sky'))return;
  const sky=document.createElement('div');sky.className='living-sky';
  sky.innerHTML='<div class="night-stars">'+Array.from({length:22},(_,i)=>`<i style="--x:${(i*37+11)%100}%;--y:${(i*23+7)%66}%;--delay:${-i*.4}s"></i>`).join('')+'</div><div class="sky-cloud c1"></div><div class="sky-cloud c2"></div><div class="sky-mist"></div><div class="weather-particles">'+Array.from({length:24},(_,i)=>`<i style="--x:${(i*17+3)%103}%;--delay:${-i*.39}s;--duration:${3+i%5}s"></i>`).join('')+'</div><div class="season-particles">'+Array.from({length:7},(_,i)=>`<i style="--x:${10+i*13}%;--delay:${-i*2.1}s;--duration:${9+i}s"></i>`).join('')+'</div>';
  portal.querySelector('.portal-frame').append(sky);
 }
 function apply(){
  panel.hidden=state.theme!=='sunset';if(panel.hidden)return;
  addScene();const c=current(),p=A.palette(c.phase,c.season,c.weather),s=A.seasons[c.season],dark=c.phase==='night'||c.phase==='dusk';
  document.body.dataset.sunPhase=c.phase;document.body.dataset.sunSeason=c.season;document.body.dataset.sunWeather=c.weather;
  const vars={...p,'on-accent':dark?'#302536':'#fff8ee',line:dark?'#eadbec24':'#54323b24',soft:dark?'#edbcad12':'#9d4d450b'};
  ['bg','side','surface','surface2','ink','muted','accent','secondary','on-accent','line','soft'].forEach(k=>document.body.style.setProperty('--living-'+k,vars[k]));
  s.hills.forEach((v,i)=>document.body.style.setProperty('--living-hill-'+i,v));p.sky.forEach((v,i)=>document.body.style.setProperty('--living-sky-'+i,v));
  const sunY=dark?19:Math.max(15,Math.min(48,48-Math.sin(Math.PI*Math.max(0,Math.min(1,(c.hour-6)/12)))*33));document.body.style.setProperty('--living-sun-y',sunY+'%');
  const preview=env.hour!==null||env.season!=='auto'||env.weather!=='auto';
  q('#living-status').textContent=`${preview?'PREVIEW':'FOLLOWING YOUR DAY'} · ${p.label} · ${s.label}`;
  const minutes=Math.round(c.hour*60);q('#sunset-time').textContent=`${String(Math.floor(minutes/60)).padStart(2,'0')}:${String(minutes%60).padStart(2,'0')}`;
  if(document.activeElement!==q('#sunset-hour'))q('#sunset-hour').value=minutes;
  q('#sunset-now').setAttribute('aria-pressed',String(env.hour===null));q('#sunset-now').textContent=env.hour===null?'Following clock':'Back to now';
  q('#hero-eyebrow').textContent=`${p.label.toUpperCase()} / A LITTLE ROOM FOR WONDER`;
  q('#scene-coordinate').textContent=`${s.label.toUpperCase()} / ${env.weather==='auto'&&!c.data?'CLOCK & CALENDAR':A.weatherNames[c.weather].toUpperCase()}${env.weather!=='auto'?' / PREVIEW':''}`;
  q('.sunset-stamp').textContent={dawn:'a gentle beginning.',day:'follow the light.',golden:'a new perspective.',dusk:'a little afterglow.',night:'under the same moon.'}[c.phase];
  q('#direction-caption').textContent='05 — Sunset Scholar / a living window, from first light to moonlight.';
  q('#theme-summary').textContent='The world changes. Your desk follows.';
  q('#theme-explanation').textContent='Warmth through the day, plum after dark, and a landscape that follows the season. Let the weather into your window.';
  q('#effect-chips').innerHTML='<span>Daylight → golden hour → moonlight</span><span>Five seasonal landscapes</span><span>Optional local weather · free for personal use</span>';
  q('#weather-summary').textContent=env.enabled&&env.location?env.location.name:'Optional · no API key';
  q('#weather-refresh').disabled=!env.enabled||!env.location||env.busy;q('#weather-disconnect').disabled=!env.enabled&&!env.busy;
  let text=env.busy?(statusMessage||'Checking local weather…'):statusMessage;
  if(!text){if(c.data){const age=Math.floor((Date.now()-c.data.fetchedAt)/60000);text=`${env.location.name} · ${Math.round(c.data.temperature)}°C · ${A.weatherNames[A.weatherKind(c.data.code)]} · ${age<1?'updated just now':`updated ${age} min ago`}`;}else text=env.enabled?'Weather unavailable. Using clock & calendar.':'Clock & calendar active. Choose a city to add real weather.';}
  if(failed)text+=c.data?' Showing recent saved weather.':' Clock & calendar are still active.';
  if(env.weather!=='auto')text=`${A.weatherNames[env.weather]} is a visual preview. ${text}`;
  q('#weather-status').textContent=text;
  const next=`${c.phase}/${c.season}/${c.weather}`;if(next!==signature){signature=next;q('.sunset-portal').setAttribute('data-scene',next);}
 }
 function begin(message){request?.abort();request=new AbortController();revision++;env.busy=true;failed=false;statusMessage=message;apply();return {signal:request.signal,id:revision};}
 async function json(url,signal){const timeout=setTimeout(()=>request?.signal===signal&&request.abort(),10000);try{const response=await fetch(url,{signal,referrerPolicy:'no-referrer',credentials:'omit'});if(!response.ok)throw new Error('Weather service is unavailable.');return await response.json();}finally{clearTimeout(timeout);}}
 function failure(id,message){if(id!==revision)return;env.busy=false;failed=true;statusMessage=message;apply();}
 async function fetchWeather(force=false){
  if(!env.enabled||!env.location||env.busy)return;
  if(!force&&fresh()&&Date.now()-env.cache.fetchedAt<30*60000)return;
  if(!force&&Date.now()-env.lastAttempt<10*60000)return;
  const task=begin('Checking local weather…');env.lastAttempt=Date.now();
  const params=new URLSearchParams({latitude:env.location.latitude,longitude:env.location.longitude,current:'temperature_2m,weather_code,is_day',daily:'sunrise,sunset',timezone:'auto',timeformat:'unixtime',forecast_days:'1'});
  try{const data=await json('https://api.open-meteo.com/v1/forecast?'+params,task.signal);if(task.id!==revision)return;env.cache=A.parseWeather(data,env.location);env.location.timezone=env.cache.timezone;write(':weather',env.cache);persist();env.busy=false;statusMessage='';apply();}catch{failure(task.id,'Could not refresh weather.');}
 }
 function useLocation(location){
  request?.abort();revision++;env.busy=false;env.location=location;env.enabled=true;env.lastAttempt=0;statusMessage='';
  env.profile=location.latitude<0?'south':location.country_code==='IN'?'monsoon':'north';q('#sunset-profile').value=env.profile;
  persist();q('#weather-results').replaceChildren();apply();fetchWeather(true);
 }
 q('#weather-city-form').addEventListener('submit',async e=>{
  e.preventDefault();const city=q('#weather-city').value.trim();if(city.length<2)return;
  const task=begin('Finding your city…');q('#weather-results').replaceChildren();
  try{const data=await json('https://geocoding-api.open-meteo.com/v1/search?'+new URLSearchParams({name:city,count:'5',language:'en',format:'json'}),task.signal);if(task.id!==revision)return;
   results=(data.results||[]).filter(x=>validLocation(x));env.busy=false;statusMessage=results.length?'Choose your city below.':'No matching city. Try a nearby city or a different spelling.';
   results.forEach(city=>{const button=document.createElement('button');button.type='button';button.textContent=[city.name,city.admin1,city.country].filter(Boolean).join(', ');button.addEventListener('click',()=>useLocation({...city,name:button.textContent}));q('#weather-results').append(button);});apply();
  }catch{failure(task.id,'City search is unavailable. Try again when connected.');}
 });
 q('#weather-locate').addEventListener('click',()=>{
  if(!navigator.geolocation){statusMessage='Location is unavailable here. Search by city instead.';apply();return;}
  const task=begin('Waiting for location permission…');
  navigator.geolocation.getCurrentPosition(position=>{if(task.id!==revision)return;useLocation({name:'Near you',latitude:Math.round(position.coords.latitude*100)/100,longitude:Math.round(position.coords.longitude*100)/100});},()=>failure(task.id,'Location was not available. Search by city instead.'),{enableHighAccuracy:false,timeout:12000,maximumAge:30*60000});
 });
 q('#weather-refresh').addEventListener('click',()=>fetchWeather(true));
 q('#weather-disconnect').addEventListener('click',()=>{revision++;request?.abort();env.busy=false;failed=false;env.enabled=false;env.location=null;env.cache=null;env.lastAttempt=0;statusMessage='Weather off. Following your device clock and calendar.';write(':weather',null);persist();q('#weather-results').replaceChildren();apply();});
 q('#sunset-hour').addEventListener('input',e=>{env.hour=Number(e.target.value)/60;apply();});
 q('#sunset-now').addEventListener('click',()=>{env.hour=null;apply();});
 q('#sunset-season').addEventListener('change',e=>{env.season=e.target.value;apply();});
 q('#sunset-weather').addEventListener('change',e=>{env.weather=e.target.value;apply();});
 q('#sunset-profile').addEventListener('change',e=>{env.profile=e.target.value;persist();apply();});
 document.addEventListener('study-theme-change',apply);
 const tick=()=>{apply();if(!document.hidden&&state.theme==='sunset'&&env.weather==='auto')fetchWeather();};
 setInterval(tick,60000);document.addEventListener('visibilitychange',()=>{if(!document.hidden)tick();});
 setTheme('sunset');apply();fetchWeather();
})();
