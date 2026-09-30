import { t } from './i18n.js';
import { getLevel, THEMES } from './levels.js';
import { objectiveFor } from './engagement.js';
import { DESTINATIONS, REWARDS, MEDAL_IDS, journeyCounts, claimReward } from './progression.js';
import { drawSkinInside, drawSkinRim } from './cosmetics.js';

const el = (tag, className, text) => {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
};
const button = (label, action, disabled=false) => {
  const node = el('button','btn',label);node.disabled=disabled;node.addEventListener('click',action);return node;
};
export const rewardName = reward => t(`${reward.slot === 'skin' ? 'skin' : reward.slot === 'fx' ? 'fx' : 'trail'}_${reward.item}`);

export class JourneyView {
  constructor(save, portrait, onPlay, onChange) {
    Object.assign(this,{save,portrait,onPlay,onChange});
    this.tab='map';this.page=0;
  }
  open() { this.page=Math.floor((this.save.level-1)/9);this.render(); }
  render() {
    const tabs=document.getElementById('journey-tabs');tabs.replaceChildren();
    for(const [id,key] of [['map','travelMap'],['collection','passport'],['rewards','rewards']]) {
      const b=button(t(key),()=>{this.tab=id;this.render();});b.className=`tab ${id===this.tab?'active':''}`;
      b.setAttribute('aria-pressed',String(id===this.tab));tabs.append(b);
    }
    const counts=journeyCounts(this.save.journey);
    document.getElementById('journey-total').textContent=t('journeyTotals',counts);
    const body=document.getElementById('journey-content');body.replaceChildren();
    if(this.tab==='map') this.map(body);
    else if(this.tab==='collection') this.collection(body);
    else this.rewards(body);
    body.scrollTop=0;
  }
  map(body) {
    const start=this.page*9+1,end=start+8;
    const nav=el('div','chapter-nav');
    nav.append(button('← '+t('previous'),()=>{this.page--;this.render();},this.page===0));
    const heading=el('div');heading.append(el('h3','',t('chapter',{n:this.page+1})),el('p','',t('chapterRange',{a:start,b:end})));
    nav.append(heading,button(t('nextChapter')+' →',()=>{this.page++;this.render();},end>=Math.ceil(this.save.level/THEMES.length)*THEMES.length));body.append(nav);
    const map=el('div','world-atlas');map.setAttribute('aria-hidden','true');
    // An illustrated atlas backdrop; the numbered route is schematic, not coordinates.
    map.innerHTML=`<svg viewBox="0 0 800 260" focusable="false"><defs><pattern id="atlas-grid" width="40" height="40" patternUnits="userSpaceOnUse"><path d="M40 0H0V40" fill="none" stroke="#ffffff" stroke-opacity=".06"/></pattern></defs><rect width="800" height="260" fill="url(#atlas-grid)"/><g fill="#3c827c" stroke="#82c4a4" stroke-width="2"><path d="M82 42L163 23 209 40 222 65 193 82 163 94 162 125 136 137 126 109 97 98 68 70Z"/><path d="M166 135L204 129 232 153 213 177 205 215 181 239 169 204 153 170Z"/><path d="M278 22L310 14 335 26 311 56 285 52Z"/><path d="M351 55L391 40 421 56 414 85 376 100 343 81Z"/><path d="M367 99L427 91 453 124 434 164 409 197 384 171 374 142 347 123Z"/><path d="M428 45L497 20 553 33 602 28 662 51 704 69 680 99 621 104 601 126 570 116 550 155 526 142 511 104 467 95 450 77Z"/><path d="M640 184L681 169 721 180 737 211 705 234 663 224 640 205Z"/><path d="M611 157L644 154 660 164 632 171Z"/></g><path d="M80 162Q160 18 240 109T400 131T560 87T720 166" fill="none" stroke="#ffda83" stroke-width="3" stroke-dasharray="7 8"/></svg>`;
    const positions=[[10,62],[20,36],[30,42],[40,55],[50,50],[60,31],[70,33],[80,47],[90,64]];
    positions.forEach(([x,y],i)=>{const n=start+i,pin=el('span',`atlas-pin ${n<this.save.level?'visited':n===this.save.level?'here':''}`,String(n));pin.style.left=`${x}%`;pin.style.top=`${y}%`;map.append(pin);});
    body.append(map);
    const grid=el('div','route-grid');
    for(let n=start;n<=end;n++) {
      const level=getLevel(n),theme=level.theme,owned=this.save.journey.medals[n]||[];
      const tile=button('',()=>this.onPlay(n),n>this.save.level);
      tile.className=`route-stop ${n===this.save.level?'current':''} ${n>this.save.level?'locked':''}`;
      const portrait=el('canvas');this.portrait(portrait,theme);tile.append(portrait);
      tile.append(el('span','route-number',`${n>this.save.level?'🔒 ':''}${t('level')} ${n}`),el('b','',t(`${theme.boss}Boss`)));
      const stars=this.save.stars[n-1]||0;
      tile.append(el('span','route-stars','★'.repeat(stars)+'☆'.repeat(3-stars)));
      const medals=el('span','route-medals');
      for(const id of MEDAL_IDS) {const m=el('span',owned.includes(id)?'earned':'',({task:'◆',quick:'⚡',clean:'✦'})[id]);m.title=t(`medal_${id}`);medals.append(m);}
      tile.append(medals);tile.setAttribute('aria-label',`${t('level')} ${n}: ${t(`${theme.boss}Boss`)}. ${t('medalPreview',{n:owned.length})}`);
      const challenge=objectiveFor(n);
      tile.append(el('span','route-goal',t(challenge.key,{n:challenge.goal})),el('span','route-time',`⚡ ${level.quickTarget}s · ✦ 90%`));
      tile.title=`${t(challenge.key,{n:challenge.goal})} · ${t('medalQuickHelp',{s:level.quickTarget})} · ${t('medalCleanHelp')}`;
      grid.append(tile);
    }
    body.append(grid);
    const guide=el('div','medal-guide');
    for(const [id,key] of [['task','medalTaskHelp'],['quick','medalQuickHelp'],['clean','medalCleanHelp']]) {
      guide.append(el('p','',`${t('medal_'+id)} · ${t(key,{s:getLevel(Math.max(start,Math.min(end,this.save.level))).quickTarget})}`));
    }
    body.append(guide);
  }
  collection(body) {
    const grid=el('div','passport-grid');
    for(const theme of DESTINATIONS) {
      const collected=this.save.journey.stamps.includes(theme.boss);
      const n=THEMES.findIndex(th=>th.boss===theme.boss)+1;
      const card=el('article',`stamp-card ${collected?'collected':'uncollected'}`);
      const canvas=el('canvas');this.portrait(canvas,theme);card.append(canvas);
      card.append(el('span','stamp-status',collected?'✓ '+t('stampOwned'):'🔒'),el('h3','',t(theme.boss+'Boss')),
        el('p','',t(theme.boss+'Name')),button(collected?t('replay'):t('stampLocked',{n}),()=>this.onPlay(n),n>this.save.level));
      grid.append(card);
    }
    body.append(grid);
  }
  rewards(body) {
    const grid=el('div','reward-grid'),counts=journeyCounts(this.save.journey);
    for(const reward of REWARDS) {
      const claimed=this.save.journey.claimed.includes(reward.id),ready=counts[reward.track]>=reward.need;
      const card=el('article',`reward-card ${ready?'ready':''}`);
      if(reward.slot==='skin') {
        const canvas=el('canvas');canvas.width=canvas.height=120;const ctx=canvas.getContext('2d');
        drawSkinInside(ctx,reward.item,60,60,38,0);drawSkinRim(ctx,reward.item,60,60,38,0,0);card.append(canvas);
      } else card.append(el('div','reward-icon',reward.slot==='fx'?'🎉':'🌈'));
      card.append(el('h3','',rewardName(reward)),el('p','',t(reward.track==='medals'?'rewardMedals':'rewardStamps',{n:reward.need})));
      const progress=el('progress');progress.max=reward.need;progress.value=Math.min(reward.need,counts[reward.track]);progress.setAttribute('aria-label',rewardName(reward));card.append(progress);
      card.append(el('span','',`${Math.min(counts[reward.track],reward.need)}/${reward.need}`));
      card.append(button(t(claimed?'rewardClaimed':ready?'claimReward':'rewardLocked'),()=>{
        if(claimReward(this.save.journey,this.save.owned,reward.id)) {this.onChange();this.render();}
      },claimed||!ready));grid.append(card);
    }
    body.append(grid);
  }
}
