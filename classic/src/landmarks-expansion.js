// Architectural miniatures. All coordinates are relative to the gameplay radius.
const TAU=Math.PI*2;
function shape(c,pts,color) {c.fillStyle=color;c.beginPath();pts.forEach(([x,y],i)=>i?c.lineTo(x,y):c.moveTo(x,y));c.closePath();c.fill();}
function stone(c,x,y,w,h,color='#ecd3a5') {
  const g=c.createLinearGradient(x,y,x+w,y+h);g.addColorStop(0,'#fff6dc');g.addColorStop(0.35,color);g.addColorStop(1,'#a87862');
  c.fillStyle=g;c.fillRect(x,y,w,h);
  c.fillStyle='rgba(255,255,255,0.5)';c.fillRect(x,y,w,0.015);
}
function arch(c,x,y,w,h,color='#534861') {
  c.fillStyle=color;c.beginPath();c.moveTo(x-w/2,y+h);c.lineTo(x-w/2,y+w/2);
  c.arc(x,y+w/2,w/2,Math.PI,0);c.lineTo(x+w/2,y+h);c.closePath();c.fill();
}
function water(c,time) {
  c.fillStyle='#479fae';c.beginPath();c.ellipse(0,0.82,1.04,0.18,0,0,TAU);c.fill();
  c.strokeStyle='#bcf5ec';c.lineWidth=0.018;
  for(let i=0;i<5;i++) {const x=-0.8+i*0.34;c.beginPath();c.moveTo(x,0.84+Math.sin(time+i)*0.025);c.lineTo(x+0.15,0.84+Math.sin(time+i)*0.025);c.stroke();}
}
const DRAW={
  sydney(c,t) {
    water(c,t);stone(c,-0.94,0.54,1.88,0.18,'#d8b78d');
    // Overlapping sail shells, shaded separately to preserve their silhouettes.
    for(const [x,y,w,h] of [[0.14,0.57,0.79,1.06],[-0.12,0.54,0.69,1.5],[-0.47,0.55,0.62,1.28],[-0.86,0.57,0.58,0.82]]) {
      const g=c.createLinearGradient(x,y-h,x+w,y);g.addColorStop(0,'#ffffff');g.addColorStop(0.48,'#fff1d7');g.addColorStop(1,'#87a9b4');
      c.fillStyle=g;c.beginPath();c.moveTo(x,y);c.quadraticCurveTo(x+w*0.55,y-h*0.25,x+w*0.72,y-h);
      c.quadraticCurveTo(x+w*1.2,y-h*0.34,x+w,y);c.closePath();c.fill();
      c.strokeStyle='#c3d3d4';c.lineWidth=0.017;c.stroke();
      c.beginPath();c.moveTo(x+w*0.72,y-h);c.lineTo(x+w*0.45,y);c.stroke();
    }
    c.fillStyle='#406179';for(let i=0;i<13;i++) c.fillRect(-0.82+i*0.13,0.59,0.075,0.09);
  },
  petra(c) {
    shape(c,[[-1,0.85],[-0.94,-0.45],[-0.65,-1.06],[-0.23,-0.91],[0.11,-1.1],[0.64,-0.89],[1,0.87]],'#c88777');
    stone(c,-0.78,-0.29,1.56,1.12,'#dfaa93');
    stone(c,-0.66,-0.76,1.32,0.48,'#e9b39d');
    arch(c,0,0.05,0.35,0.73,'#704d50');
    for(const x of [-0.63,-0.42,0.42,0.63]) {
      stone(c,x-0.045,-0.23,0.09,0.96,'#e8b596');stone(c,x-0.075,-0.24,0.15,0.07);stone(c,x-0.075,0.7,0.15,0.07);
    }
    for(const x of [-0.51,0,0.51]) {stone(c,x-0.08,-0.73,0.16,0.43);arch(c,x,-0.65,0.075,0.2);}
    shape(c,[[-0.87,-0.28],[0,-0.64],[0.87,-0.28]],'#f1c2a9');
    shape(c,[[-0.55,-0.79],[0,-1.06],[0.55,-0.79]],'#f5c8ad');
    for(let i=0;i<3;i++) stone(c,-0.87-i*0.04,0.78+i*0.055,1.74+i*0.08,0.045);
  },
  pagoda(c,t) {
    water(c,t);stone(c,-0.55,0.69,1.1,0.15,'#cdb58a');
    for(let i=0;i<11;i++) {
      const y=0.66-i*0.145,w=0.54-i*0.032;
      stone(c,-w/2,y-0.12,w,0.125,'#b95540');
      arch(c,0,y-0.105,w*0.22,0.094,'#61392e');
      shape(c,[[-w*0.74,y-0.11],[-w*0.5,y-0.17],[0,y-0.2],[w*0.5,y-0.17],[w*0.74,y-0.11]],'#dc8852');
      c.strokeStyle='#ffe1a0';c.lineWidth=0.013;c.beginPath();c.moveTo(-w*0.74,y-0.11);c.lineTo(w*0.74,y-0.11);c.stroke();
    }
    c.strokeStyle='#e8b354';c.lineWidth=0.025;c.beginPath();c.moveTo(0,-0.97);c.lineTo(0,-1.18);c.stroke();
    c.fillStyle='#ffd675';c.beginPath();c.arc(0,-1.12,0.045,0,TAU);c.fill();
    for(const s of [-1,1]) {stone(c,s*0.66-0.15,0.43,0.3,0.25,'#cd704e');shape(c,[[s*0.66-0.23,0.46],[s*0.66,0.24],[s*0.66+0.23,0.46]],'#ad463b');}
  },
  burj(c) {
    c.fillStyle='#78ccda';c.beginPath();c.ellipse(0,0.82,0.76,0.13,0,0,TAU);c.fill();
    for(let i=0;i<8;i++) {
      const x=-0.38+i*0.055,y=0.5-i*0.2,w=0.67-i*0.076,h=0.3+i*0.2;
      const g=c.createLinearGradient(x,0,x+w,0);g.addColorStop(0,'#9fe5f3');g.addColorStop(0.35,'#eefcff');g.addColorStop(0.5,'#6faccb');g.addColorStop(1,'#426788');
      c.fillStyle=g;c.fillRect(x,y,w,h);
      c.strokeStyle='#d1f4ff';c.lineWidth=0.009;
      for(let row=y+0.04;row<0.79;row+=0.055) {c.beginPath();c.moveTo(x,row);c.lineTo(x+w,row);c.stroke();}
    }
    c.strokeStyle='#b6e8f8';c.lineWidth=0.024;c.beginPath();c.moveTo(0.05,-0.92);c.lineTo(0.05,-1.23);c.stroke();
    stone(c,-0.64,0.78,1.28,0.1,'#dee9e9');
  },
  sphinx(c) {
    stone(c,-0.98,0.75,1.96,0.16,'#d5ab70');
    const g=c.createLinearGradient(-0.7,-0.6,0.7,0.8);g.addColorStop(0,'#ffdf9e');g.addColorStop(1,'#bf874b');
    c.fillStyle=g;c.beginPath();c.ellipse(0.32,0.48,0.62,0.31,0,0,TAU);c.fill();
    shape(c,[[-0.53,0.54],[-0.63,-0.51],[-0.43,-0.85],[0.01,-0.83],[0.25,-0.45],[0.12,0.6]],'#e1b36f');
    stone(c,-0.4,-0.64,0.37,0.55,'#ecc58b');
    for(let i=0;i<6;i++) {c.strokeStyle='#9a784c';c.lineWidth=0.024;c.beginPath();c.moveTo(-0.58,-0.4+i*0.12);c.lineTo(-0.44,-0.35+i*0.12);c.moveTo(0.03,-0.4+i*0.12);c.lineTo(0.16,-0.34+i*0.12);c.stroke();}
    c.fillStyle='#805f40';c.fillRect(-0.35,-0.43,0.09,0.035);c.fillRect(-0.18,-0.43,0.09,0.035);
    shape(c,[[-0.24,-0.4],[-0.3,-0.23],[-0.18,-0.23]],'#b08753');
    c.fillRect(-0.31,-0.16,0.18,0.025);
    stone(c,-0.8,0.54,0.25,0.22,'#efcb8f');stone(c,-0.44,0.56,0.28,0.2,'#efcb8f');
    for(let i=0;i<3;i++) {c.fillStyle='#b18a55';c.fillRect(-0.76+i*0.067,0.68,0.016,0.075);}
  },
  saintbasil(c) {
    stone(c,-0.95,0.78,1.9,0.12,'#e6e5de');
    for(const [x,y,h,color] of [[-0.66,-0.35,1.13,'#50ac87'],[0.66,-0.25,1.03,'#e26a70'],[-0.33,-0.64,1.42,'#dfac41'],[0.33,-0.7,1.48,'#69b0d6'],[0,-0.98,1.76,'#da535e']]) {
      stone(c,x-0.14,y+0.25,0.28,h-0.25,'#cc7965');
      arch(c,x,y+0.44,0.1,Math.max(0.16,h-0.6),'#5a536d');
      const g=c.createLinearGradient(x-0.25,y,x+0.25,y);g.addColorStop(0,'#ffe8b0');g.addColorStop(0.3,color);g.addColorStop(1,'#755477');c.fillStyle=g;
      c.beginPath();c.moveTo(x,y-0.15);c.bezierCurveTo(x-0.05,y+0.04,x-0.35,y+0.04,x-0.21,y+0.29);c.lineTo(x+0.21,y+0.29);c.bezierCurveTo(x+0.35,y+0.04,x+0.05,y+0.04,x,y-0.15);c.fill();
      c.strokeStyle='#fff0bd';c.lineWidth=0.019;for(let i=-1;i<=1;i++) {c.beginPath();c.moveTo(x,y-0.07);c.quadraticCurveTo(x+i*0.23,y+0.11,x+i*0.13,y+0.28);c.stroke();}
      c.strokeStyle='#edc573';c.lineWidth=0.018;c.beginPath();c.moveTo(x,y-0.27);c.lineTo(x,y-0.12);c.moveTo(x-0.045,y-0.22);c.lineTo(x+0.045,y-0.22);c.stroke();
    }
  },
};
export function drawNewLandmark(ctx,type,r,time) {
  if(!DRAW[type]) return false;
  ctx.save();ctx.scale(r,r);DRAW[type](ctx,time);ctx.restore();return true;
}
