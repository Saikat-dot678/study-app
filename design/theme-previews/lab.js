/* Local design prototype. Optional weather lives in sunset.js; no access to app files. */
'use strict';
const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
const icon = name => `<svg aria-hidden="true"><use href="#i-${name}"/></svg>`;
const escapeHTML = value => String(value).replace(/[&<>"']/g, character => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[character]));
const storagePrefix = 'study-atmosphere-lab-v3:';
function readLocal(key, fallback) { try { return JSON.parse(localStorage.getItem(storagePrefix + key)) ?? fallback; } catch { return fallback; } }
function saveLocal(key, value) { try { localStorage.setItem(storagePrefix + key, JSON.stringify(value)); return true; } catch { return false; } }

const themes = [
 {id:'aurora',name:'Aurora',full:'Aurora Focus',swatch:'#bda9fc',eyebrow:'A PLACE FOR YOUR NEXT BIG IDEA',title:'Stay curious.<br><em>Go deeper.</em>',description:'The best ideas don’t arrive all at once.<br>Give yours a little room to unfold.',coordinate:'ORBITAL STUDIES / 001',caption:'the art of getting lost in a good idea.',summary:'A little wonder. A lot of clarity.',explanation:'An original orbital sculpture, slow-moving light, and surfaces that respond to your touch.',effects:['Living orbital sculpture','Pointer-responsive depth','Soft, staggered arrivals']},
 {id:'paper',name:'Paper',full:'Paper Studio',swatch:'#d3d8b7',eyebrow:'A GOOD DAY TO TURN THE PAGE',title:'Collect thoughts.<br><em>Make meaning.</em>',description:'A desk for the things you’re learning.<br>And the things you haven’t figured out yet.',coordinate:'THE EVERYDAY EDITION / 002',caption:'a thoughtful desk, with room in the margins.',summary:'Ideas with a little more texture.',explanation:'An editorial composition with tactile paper, delicate rules, and notes that unfold as you explore.',effects:['Layered paper parallax','Tactile cover movement','Quiet editorial transitions']},
 {id:'neon',name:'Neon',full:'Neon Night Lab',swatch:'#d2ff73',eyebrow:'YOUR MIND / FULL SIGNAL',title:'Less noise.<br><em>More signal.</em>',description:'Build connections. Follow the interesting bits.<br>This is where your next breakthrough begins.',coordinate:'SIGNAL LAB / SYSTEM 003',caption:'a precise instrument for a curious mind.',summary:'For the hours when everything clicks.',explanation:'An animated geometric field, crisp controls, and sharp typographic contrast. Energy with a purpose.',effects:['Rotating wire sculpture','Moving signal scan','Reactive lecture waveforms']},
 {id:'forest',name:'Forest',full:'Forest Desk',swatch:'#b4c99a',eyebrow:'NOT EVERYTHING NEEDS TO HAPPEN FAST',title:'A quieter mind.<br><em>A wider world.</em>',description:'Take your time. Follow a question.<br>Good things grow with a little attention.',coordinate:'GROWTH OBSERVATIONS / 004',caption:'a small clearing for deep, unhurried work.',summary:'Let your curiosity put down roots.',explanation:'Botanical forms breathe beside your work. Soft curves and warm moss colors create a calmer rhythm.',effects:['Slow botanical sway','Floating light particles','Breathing focus dial']},
 {id:'sunset',name:'Sunset',full:'Sunset Scholar',swatch:'#dfad8e',eyebrow:'EVERY CHAPTER IS A NEW HORIZON',title:'Make room<br><em>for wonder.</em>',description:'A little warmth. A little possibility.<br>A place to see where your ideas take you.',coordinate:'GOLDEN HOUR / STUDY 005',caption:'warm light, fresh perspectives, new beginnings.',summary:'The optimism of an open window.',explanation:'A moving architectural sunset, tactile surfaces, and generous type. Warm enough to stay awhile.',effects:['Living golden-hour scene','Layered landscape parallax','Soft spring interactions']}
];
const materials = [
 {id:'normalization',title:'The art of a better database',subject:'DBMS',type:'PDF',space:'Semester 5',meta:'Normalization · page 42 of 86',progress:49,number:'03',kicker:'DATABASE SYSTEMS',short:'NORMALIZATION'},
 {id:'networks',title:'How the internet finds its way',subject:'NETWORKS',type:'VIDEO',space:'Semester 5',meta:'Routing protocols · 18:24 / 45:00',progress:41,number:'07',kicker:'COMPUTER NETWORKS',short:'ROUTING & CONNECTIONS'},
 {id:'research',title:'Small signals, big possibilities',subject:'LORA MESH',type:'NOTE',space:'Research',meta:'Field notes · 3 open questions',progress:20,number:'01',kicker:'IDEAS IN PROGRESS',short:'FIELD NOTES'},
 {id:'algorithms',title:'A more elegant way through',subject:'ALGORITHMS',type:'PDF',space:'GATE 2027',meta:'Graph theory · page 12 of 54',progress:22,number:'04',kicker:'ALGORITHMS & DATA',short:'GRAPHS & PATHS'},
 {id:'operating-systems',title:'The quiet work behind everything',subject:'OPERATING SYSTEMS',type:'PDF',space:'GATE 2027',meta:'Processes · page 8 of 72',progress:11,number:'02',kicker:'OPERATING SYSTEMS',short:'PROCESSES & THREADS'},
 {id:'questions',title:'Questions I want to come back to',subject:'PERSONAL',type:'NOTE',space:'Research',meta:'A notebook for unfinished thoughts',progress:0,number:'06',kicker:'FOLLOW YOUR CURIOSITY',short:'OPEN QUESTIONS'}
];
const baseSpaces = [{name:'Semester 5',description:'6 subjects · 128 materials',number:'01'}, {name:'GATE 2027',description:'9 subjects · 84 materials',number:'02'}, {name:'Research',description:'3 projects · endless questions',number:'03'}];
const storedSpaces = readLocal('spaces', []);
const spaces = [...baseSpaces, ...(Array.isArray(storedSpaces) ? storedSpaces.filter(s => typeof s?.name === 'string' && s.name.length <= 48).map((s,i) => ({name:s.name,description:'A fresh space for new ideas',number:String(i+4).padStart(2,'0')})) : [])];
const storedStars = readLocal('stars', ['normalization']);
const stars = new Set(Array.isArray(storedStars) ? storedStars.filter(id => materials.some(m => m.id === id)) : []);
const state = {theme:'aurora',page:'home',filter:'All',space:null,list:false,motion:!matchMedia('(prefers-reduced-motion: reduce)').matches,timerMinutes:25,remaining:1500,running:false,deadline:0,searchIndex:0,searchResults:[],readerPage:42,activeMaterial:null};
let favorite = readLocal('favorite', null);
let transitionSerial = 0, toastTimeout, saveTimeout;

$('.theme-switch').innerHTML = themes.map((t,i)=>`<button class="theme-chip" data-theme-choice="${t.id}" aria-pressed="false" aria-label="${t.full}"><i style="--swatch:${t.swatch}"></i><b>0${i+1}</b>${t.name}</button>`).join('');

function renderMaterials(items, target) {
 target.innerHTML = items.length ? items.map((m,i)=>`<article class="material-card" data-kind="${m.type}" style="animation-delay:${Math.min(i,5)*.055}s">
  <button class="material-open" data-open="${m.id}" aria-label="Open ${m.title}">
   <div class="material-cover"><span class="cover-kicker">${m.kicker}</span>${m.type==='VIDEO' ? `<div class="cover-wave">${Array.from({length:24},(_,j)=>`<i style="--h:${14+(Math.sin(j*1.3)+1)*22}px;--delay:${j*-.11}s"></i>`).join('')}</div><span class="cover-play">${icon('play')}</span>` : m.type==='NOTE' ? '<div class="cover-scribble">what if…</div>' : `<span class="cover-number">${m.number}</span><span class="cover-orbit"></span>`}<span class="cover-type">${m.short}</span></div>
   <div class="material-info"><span class="file-type">${m.type} / ${m.subject}</span><h3>${m.title}</h3><p>${m.meta}</p><div class="material-progress" style="--progress:${m.progress}%"><span></span></div></div>
  </button><button class="star-button" data-star="${m.id}" aria-label="Star ${m.title}" aria-pressed="${stars.has(m.id)}">${icon('star')}</button></article>`).join('') : `<div class="empty-state"><h3>A little room to grow.</h3><p>${state.filter==='Starred'?'Star a material to keep it close.':'No sample materials here yet. Try another space or filter.'}</p></div>`;
 bindCardDepth(target);
}
function renderLibrary() {
 let list = materials.filter(m => (!state.space || m.space === state.space) && (state.filter === 'All' || state.filter==='Starred' && stars.has(m.id) || m.type===state.filter));
 renderMaterials(list,$('#library-items'));
 $('#library-items').classList.toggle('is-list',state.list);
 $('#library-path').innerHTML = `<button data-action="all-spaces">All spaces</button>${state.space?`<span>/</span><span>${escapeHTML(state.space)}</span>`:''}<span style="margin-left:auto">${list.length} sample materials</span>`;
 $$('[data-filter]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.filter===state.filter)));
 $('#layout-toggle').setAttribute('aria-label',state.list?'Switch to grid view':'Switch to list view');
 $('#layout-toggle').innerHTML=icon(state.list?'grid':'list');
}
function renderSpaces() {
 $('#spaces-grid').innerHTML=spaces.map(s=>`<button class="space-card" data-space="${escapeHTML(s.name)}"><div class="space-top">${icon('folder')}<span>${s.number} / SPACE</span></div><h3>${escapeHTML(s.name)}</h3><p>${s.description}</p>${icon('diagonal').replace('<svg','<svg class="space-arrow"')}</button>`).join('');
}
function showPage(page, options={}) {
 if(!['home','library','notes'].includes(page))return;
 const active=$(`#page-${state.page}`),next=$(`#page-${page}`);
 if(page===state.page){if(page==='library')renderLibrary();return;}
 state.page=page;
 ++transitionSerial;
 // Update visibility in one synchronous step; rapid navigation cannot leave an old panel visible.
 $$('.page').forEach(p=>p.hidden=p!==next);
 active.classList.remove('leaving');
 next.classList.remove('replaying');
 $('#current-page').textContent={home:'My desk',library:'Library',notes:'Notebook'}[page];
 $$('.primary-nav [data-page],.mobile-nav [data-page]').forEach(b=>b.dataset.page===page?b.setAttribute('aria-current','page'):b.removeAttribute('aria-current'));
 if(page==='library')renderLibrary();
 if(!options.noScroll && $('#viewport').getBoundingClientRect().top < -40) $('#viewport').scrollIntoView({block:'start',behavior:state.motion?'smooth':'instant'});
 refreshArt();
}
function toast(message){$('#toast').textContent=message;$('#toast').classList.add('visible');clearTimeout(toastTimeout);toastTimeout=setTimeout(()=>$('#toast').classList.remove('visible'),4200);}
function openDialog(id){const dialog=$(id);if(!dialog.open)dialog.showModal();}
$$('dialog').forEach(dialog=>{
 dialog.addEventListener('click',e=>{if(e.target===dialog){const r=dialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)dialog.close();}});
});

function setTheme(id,announce=false){
 const t=themes.find(t=>t.id===id)||themes[0]; state.theme=t.id;
 document.body.dataset.theme=t.id;
 $$('[data-theme-choice]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.themeChoice===t.id)));
 $('#hero-eyebrow').textContent=t.eyebrow;$('#hero-title').innerHTML=t.title;$('#hero-description').innerHTML=t.description;$('#scene-coordinate').textContent=t.coordinate;
 $('#direction-caption').textContent=`0${themes.indexOf(t)+1} — ${t.full} / ${t.caption}`;
 $('#theme-summary').textContent=t.summary;$('#theme-explanation').textContent=t.explanation;
 $('#effect-chips').innerHTML=t.effects.map(effect=>`<span>${effect}</span>`).join('');
 $('#hero-art').innerHTML=artMarkup(t.id);document.title=`Study / ${t.full} — live review`;
 updateFavorite();replay();refreshArt();if(announce)toast(`${t.full} — try moving over the artwork.`);
 document.dispatchEvent(new CustomEvent('study-theme-change',{detail:t.id}));
}
function updateFavorite(){const chosen=favorite===state.theme;$('#choose-direction').innerHTML=`${chosen?'Your saved favorite':'Save this as my favorite'} ${icon('check')}`;$('#choose-direction').setAttribute('aria-pressed',String(chosen));}
function replay(){const page=$(`#page-${state.page}`);page.classList.remove('replaying');void page.offsetWidth;if(state.motion)page.classList.add('replaying');}
function setMotion(enabled){state.motion=enabled;document.body.dataset.motion=enabled?'full':'off';$('#motion-toggle').setAttribute('aria-pressed',String(enabled));$('#motion-toggle').innerHTML=`<span class="motion-icon">✦</span><span>${enabled?'Effects on':'Effects off'}</span>`;if(!enabled){$('#hero-scene').style.setProperty('--mx',0);$('#hero-scene').style.setProperty('--my',0);$('#hero-scene').style.setProperty('--glow-x','50%');$('#hero-scene').style.setProperty('--glow-y','50%');}refreshArt();}

function renderSearch(){
 const query=$('#global-search').value.trim().toLowerCase();
 state.searchResults=materials.filter(m=>`${m.title} ${m.subject} ${m.type} ${m.space} ${m.meta}`.toLowerCase().includes(query));
 state.searchIndex=0;
 $('#search-results').innerHTML=state.searchResults.length?state.searchResults.map((m,i)=>`<button class="search-result ${i===0?'selected':''}" data-open="${m.id}">${icon(m.type==='PDF'?'book':m.type==='VIDEO'?'play':'note')}<span><strong>${m.title}</strong><small>${m.space} / ${m.subject} · ${m.type}</small></span>${icon('arrow')}</button>`).join(''):'<div class="empty-state"><h3>Keep looking.</h3><p>No matches. Try “DBMS”, “notes”, or “GATE”.</p></div>';
}
function openSearch(){openDialog('#search-dialog');$('#global-search').value='';renderSearch();$('#global-search').focus();}
$('#global-search').addEventListener('input',renderSearch);
$('#search-dialog').addEventListener('keydown',e=>{
 if(['ArrowDown','ArrowUp'].includes(e.key)&&state.searchResults.length){e.preventDefault();state.searchIndex=(state.searchIndex+(e.key==='ArrowDown'?1:-1)+state.searchResults.length)%state.searchResults.length;$$('.search-result').forEach((b,i)=>b.classList.toggle('selected',i===state.searchIndex));$$('.search-result')[state.searchIndex].scrollIntoView({block:'nearest'});}
 if(e.key==='Enter'&&document.activeElement===$('#global-search')&&state.searchResults.length){e.preventDefault();openMaterial(state.searchResults[state.searchIndex].id);}
});
document.addEventListener('keydown',e=>{if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='k'){e.preventDefault();if(!$$('dialog[open]').length)openSearch();}});

const readingPages=[
 {heading:'One fact. One place.',body:'A useful database gives every fact a clear home. When the same information appears in several rows, a small change can leave the system telling two different stories.',subheading:'Start with the dependency.',detail:'Imagine a course record that stores a student’s name, course title, and instructor together. The student name depends on the student ID. The instructor depends on the course. Separating these relationships makes each record easier to maintain.',quote:'A good structure makes the next change simpler.'},
 {heading:'From repetition to relationships.',body:'Normalization is a way of organizing data around the relationships that actually exist. Instead of keeping copies of the same fact, we keep a reference to the place where it belongs.',subheading:'Give each idea its own table.',detail:'A Students table describes students. A Courses table describes courses. An Enrollments table connects the two. Each table now has a focused responsibility, and each relationship is explicit.',quote:'Clarity comes from knowing what belongs together.'},
 {heading:'A question worth asking.',body:'Before splitting a table, ask which attributes depend on which key. Good database design starts with understanding the real meaning of the information, not just applying a rule mechanically.',subheading:'Try it on paper.',detail:'Draw three boxes: Student, Course, and Enrollment. Place each attribute where it belongs. Then draw the links. Can you update a course title without touching a student’s record?',quote:'Make the relationship visible, and the design becomes easier to reason about.'}
];
function openMaterial(id){
 const m=materials.find(m=>m.id===id);if(!m)return;
 if($('#search-dialog').open)$('#search-dialog').close();
 state.activeMaterial=m;state.readerPage=42;
 $('#reader-type').textContent=m.type==='PDF'?'READING ROOM / SAMPLE':m.type==='VIDEO'?'LECTURE ROOM / MOTION DEMO':'FIELD NOTES / SAMPLE';
 renderReader();openDialog('#reader-dialog');
}
function renderReader(){
 const m=state.activeMaterial;
 if(m.type==='PDF'){
  const page=readingPages[state.readerPage-42];
  $('#reader-content').innerHTML=`<span class="sample-label">${m.subject} / ${m.title.toUpperCase()}</span><h2>${page.heading}</h2><p>${page.body}</p><div class="reading-callout">${page.quote}</div><h3>${page.subheading}</h3><p>${page.detail}</p><p class="fine-print">Original sample text for reviewing the reader design. This prototype does not open your real files.</p><div class="reader-pagination"><button class="previous" data-reader-step="-1" ${state.readerPage===42?'disabled':''} aria-label="Previous sample page">${icon('arrow')}</button><span>Sample page ${state.readerPage} / 44</span><button data-reader-step="1" ${state.readerPage===44?'disabled':''} aria-label="Next sample page">${icon('arrow')}</button></div>`;
 }else if(m.type==='VIDEO'){
  $('#reader-content').innerHTML=`<span class="sample-label">NETWORKS / A VISUAL EXPLANATION</span><h2>Every packet<br>has a place to go.</h2><p>A small motion study for the lecture player. Follow the signal between the nodes.</p><div class="lecture-demo"><div class="lecture-nodes"><i></i><i></i><i></i><i></i><i></i></div><strong>From one idea to another.</strong><p>Animated illustration · No audio or video file loaded</p></div><p>The final app’s existing offline player would sit in this viewing surface, with playback speed, resume position, and keyboard controls.</p>`;
 }else{
  $('#reader-content').innerHTML=`<span class="sample-label">${m.subject} / IDEAS IN PROGRESS</span><h2>${m.title}</h2><p>What happens when a group of small devices can share what they know, without relying on one central connection?</p><div class="reading-callout">Small signals. Many possible paths.</div><h3>Three questions to follow</h3><p>01 — What changes when a node leaves the network?<br>02 — How could we compare latency across different routes?<br>03 — Which assumptions should we test first?</p><button class="primary-button" data-action="edit-note" style="margin-top:25px">Open your notebook ${icon('note')}</button>`;
 }
}

function timerSnapshot(){if(state.running){state.remaining=Math.max(0,Math.ceil((state.deadline-Date.now())/1000));if(state.remaining===0){state.running=false;toast('A little progress, well earned. Time for a break.');}}}
function renderTimer(){timerSnapshot();$('.timer-value').textContent=`${String(Math.floor(state.remaining/60)).padStart(2,'0')}:${String(state.remaining%60).padStart(2,'0')}`;document.body.classList.toggle('is-running',state.running);$('.focus-live').textContent=state.running?'IN SESSION':state.remaining===0?'COMPLETE':'READY';$('.focus-start').innerHTML=`${icon(state.running?'pause':'play')}<span>${state.running?'Pause a moment':state.remaining<state.timerMinutes*60&&state.remaining>0?'Continue session':'Find your focus'}</span>`;$('.focus-dial .progress').style.strokeDashoffset=String(490*(1-state.remaining/(state.timerMinutes*60)));$$('[data-minutes]').forEach(b=>{b.setAttribute('aria-pressed',String(Number(b.dataset.minutes)===state.timerMinutes));b.disabled=state.running;});}
function toggleTimer(){timerSnapshot();if(state.running)state.running=false;else{if(state.remaining<=0)state.remaining=state.timerMinutes*60;state.deadline=Date.now()+state.remaining*1000;state.running=true;}renderTimer();}
setInterval(()=>{if(state.running)renderTimer();},500);

const savedNote=readLocal('note',null);
if(savedNote&&typeof savedNote.title==='string'&&typeof savedNote.body==='string'){$('#note-title').value=savedNote.title;$('#note-body').value=savedNote.body;}
else $('#note-body').value='Things I want to understand a little better:\n\n• Why does the simplest explanation often take the longest to find?\n• A visual way to remember database normalization.\n• Could a LoRa mesh help connect a small campus?\n\nStart small. Follow the interesting question.';
function countWords(){const body=$('#note-body').value.trim();$('#word-count').textContent=`${body?body.split(/\s+/).length:0} words`;}
function saveNote(){const success=saveLocal('note',{title:$('#note-title').value,body:$('#note-body').value});$('#save-status').textContent=success?'Saved in this browser':'Session only — browser storage unavailable';countWords();}
function queueSave(){countWords();$('#save-status').textContent='Saving…';clearTimeout(saveTimeout);saveTimeout=setTimeout(saveNote,350);}
$('#note-title').addEventListener('input',queueSave);$('#note-body').addEventListener('input',queueSave);window.addEventListener('pagehide',saveNote);countWords();

document.addEventListener('click',e=>{
 const target=e.target.closest('button');if(!target)return;
 if(target.matches('.primary-button,.round-button,.theme-chip,.focus-start,.space-card,.text-button,.material-open,.star-button'))emitRipple(target,e);
 if(target.hasAttribute('data-close')){target.closest('dialog').close();return;}
 if(target.dataset.themeChoice){setTheme(target.dataset.themeChoice);return;}
 if(target.dataset.device){const phone=target.dataset.device==='phone';$('#viewport').classList.toggle('is-phone',phone);$$('[data-device]').forEach(b=>b.setAttribute('aria-pressed',String(b===target)));resizeArt();return;}
 if(target.dataset.page){if(target.dataset.page==='library'){state.space=null;state.filter='All';}showPage(target.dataset.page);return;}
 if(target.dataset.space){state.space=target.dataset.space;state.filter='All';showPage('library');renderLibrary();return;}
 if(target.dataset.open){openMaterial(target.dataset.open);return;}
 if(target.dataset.star){const id=target.dataset.star;stars.has(id)?stars.delete(id):stars.add(id);saveLocal('stars',[...stars]);$$(`[data-star="${id}"]`).forEach(b=>b.setAttribute('aria-pressed',String(stars.has(id))));if(state.page==='library'&&state.filter==='Starred')renderLibrary();toast(stars.has(id)?'Kept close. Find it in Starred.':'Removed from your starred materials.');return;}
 if(target.dataset.filter){state.filter=target.dataset.filter;renderLibrary();return;}
 if(target.dataset.minutes){state.timerMinutes=Number(target.dataset.minutes);state.remaining=state.timerMinutes*60;state.running=false;renderTimer();return;}
 if(target.dataset.readerStep){state.readerPage=Math.max(42,Math.min(44,state.readerPage+Number(target.dataset.readerStep)));renderReader();return;}
 const action=target.dataset.action;
 if(action==='search')openSearch();
 if(action==='continue')openMaterial('normalization');
 if(action==='timer')toggleTimer();
 if(action==='reset-timer'){state.running=false;state.remaining=state.timerMinutes*60;renderTimer();}
 if(action==='new-space'){openDialog('#space-dialog');$('#space-name').focus();}
 if(action==='new-note'){showPage('notes');$('#note-body').focus();toast('Your notebook is ready. Pick up any thought.');}
 if(action==='all-spaces'){state.space=null;renderLibrary();}
 if(action==='edit-note'){$('#reader-dialog').close();showPage('notes');$('#note-body').focus();}
});
$('#space-form').addEventListener('submit',e=>{e.preventDefault();const name=$('#space-name').value.trim();if(!name){$('#space-name').setCustomValidity('Give your space a name.');$('#space-name').reportValidity();return;}if(spaces.some(s=>s.name.toLowerCase()===name.toLowerCase())){$('#space-name').setCustomValidity('A space with this name already exists.');$('#space-name').reportValidity();return;}spaces.push({name,description:'A fresh space for new ideas',number:String(spaces.length+1).padStart(2,'0')});saveLocal('spaces',spaces.slice(baseSpaces.length).map(s=>({name:s.name})));renderSpaces();$('#space-dialog').close();$('#space-name').value='';toast(`“${name}” has a little room to grow.`);});
$('#space-name').addEventListener('input',()=>$('#space-name').setCustomValidity(''));
$('#motion-toggle').addEventListener('click',()=>setMotion(!state.motion));$('#replay').addEventListener('click',replay);$('#about').addEventListener('click',()=>openDialog('#about-dialog'));
$('#layout-toggle').addEventListener('click',()=>{state.list=!state.list;renderLibrary();});
$('#profile-note').addEventListener('click',()=>toast('A local design prototype. No account, server, or real library access.'));
$('#choose-direction').addEventListener('click',()=>{favorite=state.theme;const saved=saveLocal('favorite',favorite);updateFavorite();const t=themes.find(t=>t.id===favorite);toast(`${t.full}${saved?' saved as your favorite.': ' selected for this session.'} Tell me this name when you’re ready to implement it.`);});

function bindCardDepth(root){$$('.material-card',root).forEach(card=>{card.addEventListener('pointermove',e=>{if(!state.motion||e.pointerType==='touch')return;const r=card.getBoundingClientRect();card.style.setProperty('--cx',((e.clientX-r.left)/r.width-.5)*2);card.style.setProperty('--cy',((e.clientY-r.top)/r.height-.5)*2);});card.addEventListener('pointerleave',()=>{card.style.setProperty('--cx',0);card.style.setProperty('--cy',0);});});}
const pointer={x:0,y:0};
$('#hero-scene').addEventListener('pointermove',e=>{if(!state.motion||e.pointerType==='touch')return;const r=e.currentTarget.getBoundingClientRect();pointer.x=((e.clientX-r.left)/r.width-.5)*2;pointer.y=((e.clientY-r.top)/r.height-.5)*2;e.currentTarget.style.setProperty('--mx',pointer.x);e.currentTarget.style.setProperty('--my',pointer.y);e.currentTarget.style.setProperty('--glow-x',`${50+pointer.x*35}%`);e.currentTarget.style.setProperty('--glow-y',`${50+pointer.y*35}%`);});
$('#hero-scene').addEventListener('pointerleave',()=>{pointer.x=0;pointer.y=0;$('#hero-scene').style.setProperty('--mx',0);$('#hero-scene').style.setProperty('--my',0);$('#hero-scene').style.setProperty('--glow-x','50%');$('#hero-scene').style.setProperty('--glow-y','50%');});

document.addEventListener('pointermove',e=>{const button=e.target.closest('.magnetic');if(!button||!state.motion||e.pointerType==='touch')return;const r=button.getBoundingClientRect();button.style.setProperty('--button-x',`${(e.clientX-(r.left+r.width/2))*.08}px`);button.style.setProperty('--button-y',`${(e.clientY-(r.top+r.height/2))*.08}px`);});
document.addEventListener('pointerout',e=>{const button=e.target.closest('.magnetic');if(!button||button.contains(e.relatedTarget))return;button.style.setProperty('--button-x','0px');button.style.setProperty('--button-y','0px');});
function emitRipple(button,event){if(!state.motion||!button||button.dataset.ripple==='off')return;const rect=button.getBoundingClientRect(),dot=document.createElement('i');dot.className='ripple-dot';dot.style.left=`${event.clientX-rect.left}px`;dot.style.top=`${event.clientY-rect.top}px`;button.append(dot);setTimeout(()=>dot.remove(),720);}

function forestArt(){
 const branches=[{x:246,y:350,angle:-25,scale:1,color:'#a8ba83'},{x:255,y:361,angle:23,scale:1.12,color:'#cfdb9e'},{x:241,y:355,angle:-56,scale:.63,color:'#6c916f'}];
 const groups=branches.map((b,j)=>`<g class="branch ${['a','b','c'][j]}"><g transform="translate(${b.x} ${b.y}) rotate(${b.angle}) scale(${b.scale})"><path d="M0 0 Q-20 -100 5 -260" stroke="#cfce8c" stroke-width="1.2" fill="none"/>${Array.from({length:7},(_,i)=>{const y=-30-i*31;const x=-8+Math.sin(i)*5;const size=1-i*.065;return [-1,1].map(side=>`<g transform="translate(${x} ${y}) scale(${side*size} ${size})"><path d="M0 0 C14 -25 47 -35 58 -50 C62 -12 39 9 0 0" fill="${b.color}" opacity="${.9-i*.045}"/><path d="M0 0 48 -39" stroke="#153121" stroke-width=".5" opacity=".35"/></g>`).join('');}).join('')}</g></g>`).join('');
 return `<div class="forest-halo"></div><svg class="botanical" viewBox="0 0 500 400"><defs><linearGradient id="vessel" x1="0" x2="1"><stop stop-color="#d6dfa7" stop-opacity=".05"/><stop offset=".5" stop-color="#d6dfa7" stop-opacity=".18"/><stop offset="1" stop-color="#d6dfa7" stop-opacity=".04"/></linearGradient></defs><circle cx="267" cy="178" r="148" stroke="#c5d29a" stroke-opacity=".1" fill="none"/><circle cx="267" cy="178" r="128" stroke="#c5d29a" stroke-opacity=".08" fill="none"/>${groups}<path d="M196 293 Q181 382 219 390 H285 Q314 381 302 293 Z" fill="url(#vessel)" stroke="#cfdb9e" stroke-opacity=".2"/><ellipse cx="249" cy="293" rx="54" ry="8" stroke="#cfdb9e" stroke-opacity=".25" fill="#173124" fill-opacity=".2"/></svg><span class="forest-mote a"></span><span class="forest-mote b"></span><span class="forest-mote c"></span><span class="art-coordinate bottom">GROWTH TAKES ITS OWN TIME</span>`;
}
function artMarkup(id){
 if(id==='aurora')return '<div class="orb-halo"></div><div class="orb-core"></div><div class="aurora-particles">'+Array.from({length:9},(_,i)=>`<i style="--i:${i}"></i>`).join('')+'</div><canvas id="sculpture"></canvas><span class="orb-star one"></span><span class="orb-star two"></span><span class="orb-star three"></span><span class="art-coordinate top">CURIOUS BY NATURE</span><span class="orb-label">THOUGHTS IN ORBIT ↗</span><span class="art-coordinate bottom">∞ POSSIBLE CONNECTIONS</span>';
 if(id==='paper')return '<div class="paper-stack"><div class="paper-sheet back"></div><div class="paper-sheet middle"></div><div class="paper-sheet front"><i class="paper-clip"></i><small>STUDY / FIELD NOTES</small><strong>What if<br>we tried<br>something<br>different?</strong><div class="ruled"></div><span class="handwritten">a thought worth keeping ↗</span></div><div class="paper-seal">stay<br>curious</div></div><div class="paper-dust">'+Array.from({length:7},(_,i)=>`<i style="--i:${i}"></i>`).join('')+'</div><div class="paper-pencil"></div>';
 if(id==='neon')return '<div class="neon-grid"></div><div class="neon-pulses">'+Array.from({length:6},(_,i)=>`<i style="--i:${i}"></i>`).join('')+'</div><canvas id="sculpture"></canvas><span class="neon-corner"></span><span class="neon-corner second"></span><span class="neon-scan"></span><div class="neon-label"><span>SIGNAL<strong>CONNECTED</strong></span><span>STATE<strong>CURIOUS_</strong></span></div>';
 if(id==='forest')return forestArt();
 return '<div class="sunset-portal"><div class="portal-frame"><span class="sun"></span><span class="dune"></span><span class="dune second"></span><span class="dune third"></span></div><span class="sunset-orbit"></span><span class="sunset-spark one"></span><span class="sunset-spark two"></span><span class="sunset-spark three"></span><span class="sunset-stamp">a new perspective.</span></div>';
}

// Original lightweight canvas sculpture. One animation loop, capped at 30 fps.
let canvas=null,ctx=null,artFrame=0,lastFrame=0,artVisible=true,artWidth=0,artHeight=0;
const artObserver=new IntersectionObserver(entries=>{artVisible=entries[0].isIntersecting;refreshArt();},{threshold:.02});
artObserver.observe($('#hero-scene'));
function resizeArt(){
 canvas=$('#sculpture');if(!canvas)return;ctx=canvas.getContext('2d');if(!ctx)return;
 const r=canvas.getBoundingClientRect(),dpr=Math.min(devicePixelRatio||1,2);artWidth=r.width;artHeight=r.height;
 if(!artWidth||!artHeight)return;
 canvas.width=Math.round(artWidth*dpr);canvas.height=Math.round(artHeight*dpr);ctx.setTransform(dpr,0,0,dpr,0,0);drawArt(0);
}
function refreshArt(){
 cancelAnimationFrame(artFrame);artFrame=0;canvas=$('#sculpture');ctx=canvas?.getContext('2d')||null;
 if(!ctx)return;resizeArt();
 if(state.motion&&artVisible&&state.page==='home'&&!document.hidden){lastFrame=0;artFrame=requestAnimationFrame(animateArt);}
}
function animateArt(time){
 if(time-lastFrame>=32){drawArt(time*.00022);lastFrame=time;}
 artFrame=requestAnimationFrame(animateArt);
}
function project(x,y,z,time){
 const a=.93+(state.motion?pointer.y*.10:0),b=.25+time*.14+(state.motion?pointer.x*.18:0),c=-.52;
 let yy=y*Math.cos(a)-z*Math.sin(a),zz=y*Math.sin(a)+z*Math.cos(a);
 const xx=x*Math.cos(b)+zz*Math.sin(b);zz=-x*Math.sin(b)+zz*Math.cos(b);
 const xxx=xx*Math.cos(c)-yy*Math.sin(c);yy=xx*Math.sin(c)+yy*Math.cos(c);
 const scale=Math.min(artWidth,artHeight)*.29*(3.8/(3.8-zz));
 return [artWidth*.5+xxx*scale,artHeight*.49+yy*scale,zz];
}
function drawArt(time){
 if(!ctx||!artWidth||!artHeight)return;ctx.clearRect(0,0,artWidth,artHeight);
 if(state.theme==='aurora'){
  const paths=[];
  for(let ring=0;ring<48;ring++){
   const v=ring/48*Math.PI*2,points=[];let depth=0;
   for(let segment=0;segment<=128;segment++){
    const u=segment/128*Math.PI*2,twist=v+u*2+Math.sin(time)*.18;
    const radius=1+.34*Math.cos(twist),p=project(radius*Math.cos(u),radius*Math.sin(u),.34*Math.sin(twist),time);
    points.push(p);depth+=p[2];
   }
   paths.push({points,depth:depth/points.length,ring});
  }
  paths.sort((a,b)=>a.depth-b.depth);
  for(const path of paths){
   const gradient=ctx.createLinearGradient(artWidth*.15,artHeight*.2,artWidth*.85,artHeight*.8);
   gradient.addColorStop(0,'rgba(143,225,211,.80)');gradient.addColorStop(.42,'rgba(197,188,251,.90)');gradient.addColorStop(1,'rgba(123,101,221,.42)');
   ctx.strokeStyle=gradient;ctx.globalAlpha=.35+(path.depth+.5)*.40;ctx.lineWidth=1.05;
   ctx.beginPath();path.points.forEach((p,i)=>i?ctx.lineTo(p[0],p[1]):ctx.moveTo(p[0],p[1]));ctx.stroke();
  }
  ctx.globalAlpha=1;
 }else if(state.theme==='neon'){
  const rotation=time*.7;
  for(let latitude=0;latitude<13;latitude++){
   const phi=latitude/12*Math.PI,points=[];
   for(let longitude=0;longitude<=64;longitude++){
    const theta=longitude/64*Math.PI*2+rotation;
    points.push(project(Math.sin(phi)*Math.cos(theta)*1.25,Math.cos(phi)*1.25,Math.sin(phi)*Math.sin(theta)*1.25,time));
   }
   ctx.strokeStyle='rgba(210,255,115,.30)';ctx.lineWidth=.75;ctx.beginPath();points.forEach((p,i)=>i?ctx.lineTo(p[0],p[1]):ctx.moveTo(p[0],p[1]));ctx.stroke();
  }
  for(let longitude=0;longitude<20;longitude++){
   const theta=longitude/20*Math.PI*2+rotation;ctx.beginPath();
   for(let latitude=0;latitude<=48;latitude++){const phi=latitude/48*Math.PI,p=project(Math.sin(phi)*Math.cos(theta)*1.25,Math.cos(phi)*1.25,Math.sin(phi)*Math.sin(theta)*1.25,time);latitude?ctx.lineTo(p[0],p[1]):ctx.moveTo(p[0],p[1]);}
   ctx.strokeStyle='rgba(210,255,115,.28)';ctx.stroke();
  }
  for(let i=0;i<9;i++){const phi=(i+1)/10*Math.PI,theta=i*2.4+rotation,p=project(Math.sin(phi)*Math.cos(theta)*1.27,Math.cos(phi)*1.27,Math.sin(phi)*Math.sin(theta)*1.27,time);ctx.fillStyle=p[2]>0?'#d2ff73':'#8bdfd5';ctx.fillRect(p[0]-2,p[1]-2,4,4);}
 }
}
const resizeObserver=new ResizeObserver(()=>resizeArt());resizeObserver.observe($('#hero-art'));
document.addEventListener('visibilitychange',()=>{timerSnapshot();renderTimer();refreshArt();});
matchMedia('(prefers-reduced-motion: reduce)').addEventListener('change',e=>{if(e.matches)setMotion(false);});

renderMaterials(materials.slice(0,2),$('#recent-materials'));renderSpaces();renderLibrary();renderTimer();setTheme(themes.some(t=>t.id===favorite)?favorite:'aurora');setMotion(state.motion);
