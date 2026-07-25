"use client";

import { useCallback, useEffect, useRef, useState } from "react";

type HeroKey = "warden" | "mage" | "bow" | "cleric";
type Phase = "keep" | "dungeon" | "victory";

const HEROES: Record<HeroKey, { name: string; role: string; color: string; accent: string; ability: string; glyph: string }> = {
  warden: { name: "Ironwarden", role: "Bulwark", color: "#5f7f92", accent: "#d5e2dd", ability: "Shield burst", glyph: "◆" },
  mage: { name: "Ember Mage", role: "Burst", color: "#b9482f", accent: "#ffbd68", ability: "Fire nova", glyph: "✦" },
  bow: { name: "Wildbow", role: "Ranged", color: "#658a57", accent: "#c9e98b", ability: "Volley", glyph: "➶" },
  cleric: { name: "Dawn Cleric", role: "Support", color: "#b58b38", accent: "#fff2a8", ability: "Dawn ward", glyph: "✣" },
};

type Enemy = { x: number; y: number; hp: number; max: number; r: number; speed: number; kind: "wraith" | "brute" | "boss" | "spawner"; hit: number };
type Shot = { x: number; y: number; vx: number; vy: number; life: number; friendly: boolean; color: string; r: number; damage: number };
type Spark = { x: number; y: number; vx: number; vy: number; life: number; color: string; size: number };

export default function Home() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const gameRef = useRef<any>(null);
  const keysRef = useRef<Set<string>>(new Set());
  const mouseRef = useRef({ x: 0, y: 0, down: false });
  const [hero, setHero] = useState<HeroKey>("warden");
  const [phase, setPhase] = useState<Phase>("keep");
  const [essence, setEssence] = useState(0);
  const [hud, setHud] = useState({ hp: 100, max: 100, wave: 0, objective: "Choose a champion", boss: 0, ability: 0 });
  const [sound, setSound] = useState(true);

  useEffect(() => {
    setEssence(Number(localStorage.getItem("shattered-essence") || 0));
  }, []);

  const startGame = useCallback(() => {
    const max = hero === "warden" ? 135 : hero === "cleric" ? 115 : 100;
    gameRef.current = {
      hero, player: { x: 480, y: 440, hp: max, max, angle: -Math.PI / 2, attack: 0, ability: 0, dodge: 0, inv: 0 },
      enemies: [], shots: [], sparks: [], wave: 0, waveDelay: 1.1, spawnTimer: 2.8, stage: "waves", kills: 0,
      plates: [{ x: 294, y: 204, charge: 0 }, { x: 666, y: 204, charge: 0 }], gate: 0, bossSpawned: false, time: 0, shake: 0,
    };
    setHud({ hp: max, max, wave: 3, objective: "Destroy the three monster gates", boss: 0, ability: 0 });
    setPhase("dungeon");
  }, [hero]);

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      keysRef.current.add(e.key.toLowerCase());
      if ([" ", "arrowup", "arrowdown", "arrowleft", "arrowright"].includes(e.key.toLowerCase())) e.preventDefault();
    };
    const up = (e: KeyboardEvent) => keysRef.current.delete(e.key.toLowerCase());
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    return () => { window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); };
  }, []);

  useEffect(() => {
    if (phase !== "dungeon") return;
    const canvas = canvasRef.current!;
    const ctx = canvas.getContext("2d")!;
    let raf = 0;
    let last = performance.now();
    const g = gameRef.current;
    const spawnWave = (wave: number) => {
      const count = wave === 1 ? 5 : 3;
      for (let i = 0; i < count; i++) {
        const side = i % 4;
        const pos = side === 0 ? [110 + i * 95, 92] : side === 1 ? [850, 130 + i * 48] : side === 2 ? [120 + i * 95, 488] : [110, 130 + i * 48];
        const brute = wave === 2 && i % 3 === 0;
        g.enemies.push({ x: pos[0], y: pos[1], hp: brute ? 75 : 38, max: brute ? 75 : 38, r: brute ? 22 : 15, speed: brute ? 42 : 66, kind: brute ? "brute" : "wraith", hit: 0 });
      }
    };
    const spawnGates = () => {
      [[205,130],[755,130],[480,430]].forEach(([x,y]) => g.enemies.push({x,y,hp:125,max:125,r:27,speed:0,kind:"spawner",hit:0}));
      spawnWave(1);
    };
    const particles = (x: number, y: number, color: string, n = 8) => {
      for (let i = 0; i < n; i++) {
        const a = Math.random() * Math.PI * 2, s = 30 + Math.random() * 100;
        g.sparks.push({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: .35 + Math.random() * .45, color, size: 2 + Math.random() * 4 });
      }
    };
    const attack = () => {
      const p = g.player;
      if (p.attack > 0) return;
      p.attack = g.hero === "bow" ? .24 : .38;
      const ranged = g.hero === "bow" || g.hero === "mage";
      if (ranged) {
        const speed = g.hero === "bow" ? 520 : 400;
        g.shots.push({ x: p.x, y: p.y, vx: Math.cos(p.angle) * speed, vy: Math.sin(p.angle) * speed, life: 1.2, friendly: true, color: HEROES[g.hero as HeroKey].accent, r: g.hero === "mage" ? 7 : 4, damage: g.hero === "mage" ? 28 : 23 });
      } else {
        g.enemies.forEach((e: Enemy) => {
          const d = Math.hypot(e.x - p.x, e.y - p.y);
          const diff = Math.abs(Math.atan2(Math.sin(Math.atan2(e.y-p.y,e.x-p.x)-p.angle), Math.cos(Math.atan2(e.y-p.y,e.x-p.x)-p.angle)));
          if (d < 84 && diff < 1.25) { e.hp -= g.hero === "warden" ? 31 : 24; e.hit = .12; particles(e.x, e.y, HEROES[g.hero as HeroKey].accent, 5); }
        });
      }
    };
    const ability = () => {
      const p = g.player;
      if (p.ability > 0) return;
      p.ability = g.hero === "cleric" ? 5 : 4;
      particles(p.x, p.y, HEROES[g.hero as HeroKey].accent, 24);
      if (g.hero === "cleric") p.hp = Math.min(p.max, p.hp + 38);
      else if (g.hero === "bow") {
        [-.28, 0, .28].forEach(a => g.shots.push({ x:p.x,y:p.y,vx:Math.cos(p.angle+a)*500,vy:Math.sin(p.angle+a)*500,life:1.2,friendly:true,color:"#d8f596",r:5,damage:34 }));
      } else {
        g.enemies.forEach((e: Enemy) => { if (Math.hypot(e.x-p.x,e.y-p.y)<150) { e.hp -= g.hero === "mage" ? 56 : 35; e.hit=.18; }});
        g.shake = .25;
      }
    };
    const frame = (now: number) => {
      const dt = Math.min(.033, (now-last)/1000); last = now; g.time += dt;
      const p = g.player, keys = keysRef.current, mouse = mouseRef.current;
      p.attack -= dt; p.ability -= dt; p.dodge -= dt; p.inv -= dt; g.shake -= dt;
      const pad = navigator.getGamepads?.()[0];
      let dx = (keys.has("d")||keys.has("arrowright")?1:0)-(keys.has("a")||keys.has("arrowleft")?1:0);
      let dy = (keys.has("s")||keys.has("arrowdown")?1:0)-(keys.has("w")||keys.has("arrowup")?1:0);
      if (pad) {
        if (Math.abs(pad.axes[0]) > .16) dx = pad.axes[0];
        if (Math.abs(pad.axes[1]) > .16) dy = pad.axes[1];
      }
      if (dx||dy) { const l=Math.hypot(dx,dy); dx/=l;dy/=l; p.x+=dx*190*dt;p.y+=dy*190*dt; }
      p.x=Math.max(92,Math.min(868,p.x)); p.y=Math.max(84,Math.min(506,p.y));
      const rect=canvas.getBoundingClientRect(); const mx=mouse.x/rect.width*960,my=mouse.y/rect.height*540;
      if (pad && Math.hypot(pad.axes[2]||0,pad.axes[3]||0)>.35) p.angle=Math.atan2(pad.axes[3],pad.axes[2]);
      else if (mouse.x) p.angle=Math.atan2(my-p.y,mx-p.x); else if(dx||dy) p.angle=Math.atan2(dy,dx);
      if (mouse.down||keys.has(" ")||pad?.buttons[0]?.pressed) attack();
      if (keys.has("q")||keys.has("e")||pad?.buttons[2]?.pressed) ability();
      if ((keys.has("shift")||keys.has("f")||pad?.buttons[1]?.pressed)&&p.dodge<=0) { p.x+=Math.cos(p.angle)*65;p.y+=Math.sin(p.angle)*65;p.dodge=1;p.inv=.35;particles(p.x,p.y,"#c7eff0",8); }

      if (g.stage==="waves") {
        if (g.wave===0) { g.waveDelay-=dt; if(g.waveDelay<=0){g.wave=1;spawnGates();} }
        const gates=g.enemies.filter((e:Enemy)=>e.kind==="spawner");
        g.spawnTimer-=dt;
        if(g.spawnTimer<=0&&gates.length){g.spawnTimer=Math.max(1.8,3.8-g.time*.015);gates.forEach((gate:Enemy,i:number)=>{if(i<2||Math.random()>.35)g.enemies.push({x:gate.x+(Math.random()-.5)*34,y:gate.y+(Math.random()-.5)*34,hp:38,max:38,r:15,speed:68,kind:"wraith",hit:0})});}
        setHud((h:any)=>({...h,wave:gates.length}));
        if(g.wave>0&&!gates.length){g.enemies=g.enemies.filter((e:Enemy)=>e.kind==="boss"||e.kind==="spawner");g.stage="puzzle";setHud((h:any)=>({...h,wave:0,objective:"Stand on both moon seals"}));}
      } else if (g.stage==="puzzle") {
        g.plates.forEach((pl:any)=>{ if(Math.hypot(pl.x-p.x,pl.y-p.y)<48) pl.charge=Math.min(1,pl.charge+dt/1.25); });
        if(g.plates.every((pl:any)=>pl.charge>=1)){g.stage="boss";g.gate=1;setHud((h:any)=>({...h,objective:"Defeat the Crypt Warden"}));}
      } else if(g.stage==="boss"&&!g.bossSpawned){
        g.enemies.push({x:480,y:118,hp:520,max:520,r:38,speed:48,kind:"boss",hit:0});g.bossSpawned=true;particles(480,118,"#65e8df",30);
      }
      g.enemies.forEach((e:Enemy)=>{
        e.hit-=dt; const a=Math.atan2(p.y-e.y,p.x-e.x), d=Math.hypot(p.x-e.x,p.y-e.y);
        if(e.kind!=="spawner"&&d>e.r+23){e.x+=Math.cos(a)*e.speed*dt;e.y+=Math.sin(a)*e.speed*dt;}
        else if(e.kind!=="spawner"&&p.inv<=0){p.hp-= (e.kind==="boss"?24:12)*dt;p.inv=.08;g.shake=.08;}
        if(e.kind==="boss"&&Math.random()<dt*.8){const aa=Math.atan2(p.y-e.y,p.x-e.x);g.shots.push({x:e.x,y:e.y,vx:Math.cos(aa)*180,vy:Math.sin(aa)*180,life:2.5,friendly:false,color:"#5de8de",r:8,damage:12});}
      });
      g.shots.forEach((s:Shot)=>{
        s.x+=s.vx*dt;s.y+=s.vy*dt;s.life-=dt;
        if(s.friendly) g.enemies.forEach((e:Enemy)=>{if(s.life>0&&Math.hypot(s.x-e.x,s.y-e.y)<s.r+e.r){e.hp-=s.damage;e.hit=.12;s.life=0;particles(s.x,s.y,s.color,5);}});
        else if(s.life>0&&Math.hypot(s.x-p.x,s.y-p.y)<s.r+18&&p.inv<=0){p.hp-=s.damage;p.inv=.35;s.life=0;}
      });
      g.enemies=g.enemies.filter((e:Enemy)=>{if(e.hp<=0){particles(e.x,e.y,e.kind==="boss"?"#f6c264":"#65e8df",e.kind==="boss"?40:e.kind==="spawner"?24:12);if(e.kind==="spawner")p.hp=Math.min(p.max,p.hp+12);if(e.kind==="boss"){localStorage.setItem("shattered-essence",String(essence+125));setEssence(x=>x+125);setPhase("victory");}return false;}return true;});
      g.shots=g.shots.filter((s:Shot)=>s.life>0); g.sparks.forEach((s:Spark)=>{s.x+=s.vx*dt;s.y+=s.vy*dt;s.vx*=.95;s.vy*=.95;s.life-=dt;});g.sparks=g.sparks.filter((s:Spark)=>s.life>0);
      if(p.hp<=0){setPhase("keep");return;}
      const boss=g.enemies.find((e:Enemy)=>e.kind==="boss");
      setHud((h:any)=>({...h,hp:Math.max(0,Math.ceil(p.hp)),ability:Math.max(0,p.ability),boss:boss?boss.hp/boss.max:0}));

      // Draw the modular crypt.
      ctx.save(); ctx.clearRect(0,0,960,540);
      const shake=g.shake>0?4:0;ctx.translate((Math.random()-.5)*shake,(Math.random()-.5)*shake);
      const bg=ctx.createLinearGradient(0,0,0,540);bg.addColorStop(0,"#101f29");bg.addColorStop(1,"#071014");ctx.fillStyle=bg;ctx.fillRect(0,0,960,540);
      ctx.fillStyle="#182c33";ctx.fillRect(66,58,828,472);ctx.strokeStyle="#416067";ctx.lineWidth=3;ctx.strokeRect(66,58,828,472);
      for(let y=72;y<520;y+=46)for(let x=78;x<892;x+=72){ctx.fillStyle=(x/72+y/46)%2>1?"#1c3439":"#203a3e";ctx.fillRect(x+(y%92?18:0),y,64,38);ctx.strokeStyle="#13282d";ctx.lineWidth=2;ctx.strokeRect(x+(y%92?18:0),y,64,38);}
      ctx.fillStyle="#0b171b";ctx.fillRect(415,58,130,90);ctx.fillStyle=g.stage==="boss"?"#234b4e":"#121f24";ctx.fillRect(432,58,96,82);
      // pillars and braziers
      [[112,110],[848,110],[112,474],[848,474]].forEach(([x,y])=>{ctx.fillStyle="#0b151a";ctx.beginPath();ctx.ellipse(x,y+13,29,13,0,0,7);ctx.fill();ctx.fillStyle="#34484a";ctx.fillRect(x-18,y-30,36,39);ctx.fillStyle="#4b6160";ctx.fillRect(x-23,y-34,46,10);const flame=7+Math.sin(g.time*8+x)*3;ctx.fillStyle="#e77b39";ctx.beginPath();ctx.arc(x,y-42,flame,0,7);ctx.fill();ctx.fillStyle="#ffd06b";ctx.beginPath();ctx.arc(x,y-44,flame*.45,0,7);ctx.fill();});
      if(g.stage==="puzzle"||g.stage==="boss")g.plates.forEach((pl:any)=>{ctx.strokeStyle=pl.charge>=1?"#90fff2":"#438a87";ctx.lineWidth=5;ctx.beginPath();ctx.arc(pl.x,pl.y,34,0,Math.PI*2);ctx.stroke();ctx.strokeStyle="#b9fff1";ctx.beginPath();ctx.arc(pl.x,pl.y,25,-Math.PI/2,-Math.PI/2+Math.PI*2*pl.charge);ctx.stroke();ctx.fillStyle="rgba(85,236,220,.15)";ctx.beginPath();ctx.arc(pl.x,pl.y,28+Math.sin(g.time*3)*3,0,7);ctx.fill();});
      // enemies
      g.enemies.forEach((e:Enemy)=>{ctx.save();ctx.translate(e.x,e.y);ctx.fillStyle="rgba(0,0,0,.35)";ctx.beginPath();ctx.ellipse(0,e.r*.7,e.r*1.2,e.r*.55,0,0,7);ctx.fill();if(e.kind==="spawner"){ctx.rotate(g.time*.4);ctx.fillStyle=e.hit>0?"#eaffff":"#17292e";ctx.strokeStyle="#6aeee2";ctx.lineWidth=5;for(let i=0;i<4;i++){ctx.rotate(Math.PI/2);ctx.fillRect(-8,-34,16,30);ctx.strokeRect(-8,-34,16,30)}ctx.beginPath();ctx.arc(0,0,15,0,7);ctx.stroke();ctx.fillStyle="#72eee1";ctx.beginPath();ctx.arc(0,0,7+Math.sin(g.time*5)*2,0,7);ctx.fill();}else{ctx.fillStyle=e.hit>0?"#eaffff":e.kind==="boss"?"#33494d":e.kind==="brute"?"#694844":"#24535a";ctx.beginPath();ctx.arc(0,0,e.r,0,7);ctx.fill();ctx.fillStyle=e.kind==="boss"?"#d6a54c":"#62ede0";ctx.beginPath();ctx.arc(-e.r*.32,-3,3,0,7);ctx.arc(e.r*.32,-3,3,0,7);ctx.fill();if(e.kind==="boss"){ctx.strokeStyle="#76eee1";ctx.lineWidth=4;ctx.beginPath();ctx.arc(0,0,e.r+8,.2,2.9);ctx.stroke();}}ctx.restore();if(e.hp<e.max){ctx.fillStyle="#071113";ctx.fillRect(e.x-e.r,e.y-e.r-12,e.r*2,4);ctx.fillStyle=e.kind==="boss"?"#e8b24f":"#66dcd3";ctx.fillRect(e.x-e.r,e.y-e.r-12,e.r*2*(e.hp/e.max),4);}});
      // shots / sparks
      g.shots.forEach((s:Shot)=>{ctx.shadowBlur=16;ctx.shadowColor=s.color;ctx.fillStyle=s.color;ctx.beginPath();ctx.arc(s.x,s.y,s.r,0,7);ctx.fill();ctx.shadowBlur=0;});
      g.sparks.forEach((s:Spark)=>{ctx.globalAlpha=Math.max(0,s.life*2);ctx.fillStyle=s.color;ctx.fillRect(s.x,s.y,s.size,s.size);ctx.globalAlpha=1;});
      // player
      ctx.save();ctx.translate(p.x,p.y);ctx.rotate(p.angle);ctx.fillStyle="rgba(0,0,0,.4)";ctx.beginPath();ctx.ellipse(0,13,23,9,0,0,7);ctx.fill();ctx.rotate(-p.angle);ctx.fillStyle=HEROES[g.hero as HeroKey].color;ctx.beginPath();ctx.arc(0,0,18,0,7);ctx.fill();ctx.strokeStyle=HEROES[g.hero as HeroKey].accent;ctx.lineWidth=3;ctx.beginPath();ctx.arc(0,0,18,0,7);ctx.stroke();ctx.fillStyle=HEROES[g.hero as HeroKey].accent;ctx.font="18px Georgia";ctx.textAlign="center";ctx.fillText(HEROES[g.hero as HeroKey].glyph,0,6);ctx.restore();
      ctx.restore();
      raf=requestAnimationFrame(frame);
    };
    raf=requestAnimationFrame(frame);
    return()=>cancelAnimationFrame(raf);
  },[phase,essence]);

  const pointer = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const r=e.currentTarget.getBoundingClientRect();mouseRef.current.x=e.clientX-r.left;mouseRef.current.y=e.clientY-r.top;
  };
  const chosen=HEROES[hero];
  return <main className="game-shell">
    <div className="topbar"><div className="brand"><span className="sigil">SK</span><div><b>THE SHATTERED KEEP</b><small>Vertical slice · Expedition 01</small></div></div><div className="resources"><span>✦ {essence} Aether</span><button onClick={()=>setSound(!sound)} aria-label="Toggle sound">{sound?"Sound on":"Sound off"}</button></div></div>
    <section className="viewport">
      {phase==="keep"&&<div className="keep-screen">
        <div className="keep-art"><div className="moon"/><div className="tower t1"/><div className="tower t2"/><div className="tower t3"/><div className="keep-glow"/><div className="mist m1"/><div className="mist m2"/></div>
        <div className="keep-copy"><p className="eyebrow">THE KEEP · OUTER COURT</p><h1>The crypt stirs<br/><em>beneath us.</em></h1><p>Choose your first oath. Reclaim the Moon Seal and return with enough aether to relight the forge.</p><div className="class-grid">{(Object.keys(HEROES) as HeroKey[]).map(k=><button key={k} className={`class-card ${hero===k?"active":""}`} onClick={()=>setHero(k)}><span style={{background:HEROES[k].color,color:HEROES[k].accent}}>{HEROES[k].glyph}</span><div><b>{HEROES[k].name}</b><small>{HEROES[k].role} · {HEROES[k].ability}</small></div></button>)}</div><button className="embark" onClick={startGame}>Descend into the crypt <span>→</span></button></div>
      </div>}
      {phase==="dungeon"&&<><canvas ref={canvasRef} width={960} height={540} onPointerMove={pointer} onPointerDown={(e)=>{e.currentTarget.setPointerCapture(e.pointerId);mouseRef.current.down=true;pointer(e)}} onPointerUp={()=>mouseRef.current.down=false}/>
        <div className="hud top"><div className="portrait" style={{borderColor:chosen.accent,color:chosen.accent}}>{chosen.glyph}</div><div className="bars"><b>{chosen.name}</b><div className="health"><i style={{width:`${hud.hp/hud.max*100}%`}}/></div><small>{hud.hp} / {hud.max}</small></div><div className="objective"><small>OBJECTIVE</small><b>{hud.objective}</b><span>{hud.boss?`Crypt Warden · ${Math.ceil(hud.boss*100)}%`:hud.wave?`${hud.wave} monster gates remain`:"The way is open"}</span></div></div>
        <div className="hud bottom"><div><kbd>WASD</kbd><span>Move</span></div><div><kbd>Mouse / Space</kbd><span>Attack</span></div><div><kbd>Q / E</kbd><span>{chosen.ability}</span></div><div><kbd>Shift</kbd><span>Dash</span></div></div>
      </>}
      {phase==="victory"&&<div className="victory"><div className="seal">✦</div><p className="eyebrow">EXPEDITION COMPLETE</p><h2>The Moon Seal<br/>answers the Keep.</h2><div className="reward"><span>Recovered</span><b>+125 Aether</b><small>Forge ember unlocked</small></div><button className="embark" onClick={()=>setPhase("keep")}>Return to the Keep <span>→</span></button></div>}
    </section>
    <footer><span>LOCAL CO-OP PROTOTYPE</span><span>Gamepad: left stick move · right stick aim · A attack · B dash</span><span>v0.1 MOONCRYPT</span></footer>
  </main>;
}
