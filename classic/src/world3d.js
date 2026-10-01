import * as THREE from './vendor/three.module.min.js';
import { drawGround, drawObject } from './world.js';
import { drawSkinInside, drawSkinRim, drawParticles } from './cosmetics.js';

// Gameplay stays on the X/Z ground plane. Height belongs only to the renderer.
// Bundled Three.js works offline in both Playables and the native app builds.
export class World3D {
  static create(overlay) {
    if (typeof document === 'undefined' || !overlay.parentNode) return null;
    let canvas;
    try {
      canvas = document.createElement('canvas');
      canvas.className = 'world-3d';
      canvas.setAttribute('aria-hidden', 'true');
      const view = new World3D(canvas);
      overlay.before(canvas);
      return view;
    } catch (error) {
      canvas?.remove();
      console.warn('3D unavailable; using the Canvas renderer.', error);
      return null;
    }
  }

  constructor(canvas) {
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
    this.renderer.localClippingEnabled = true;
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color('#adcbd6');
    this.camera = new THREE.OrthographicCamera(-500, 500, 500, -500, 1, 16000);
    this.scene.add(new THREE.HemisphereLight('#e6f3ff', '#657365', 1.5));
    const sun = new THREE.DirectionalLight('#fff1dc', 1.6);
    sun.position.set(-700, 1400, 600);
    this.scene.add(sun);
    this.clip = new THREE.Plane(new THREE.Vector3(0, 1, 0), -0.4);
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.05;
    this.batchMaterial = new THREE.MeshLambertMaterial({ color: '#ffffff', flatShading: true, clippingPlanes: [this.clip] });
    this.shadowMaterial = new THREE.MeshBasicMaterial({ color: '#263847', opacity: 0.18, transparent: true, depthWrite: false });
    this.batches = new Map();
    this.geometry = {
      box: new THREE.BoxGeometry(1, 1, 1),
      ball: new THREE.IcosahedronGeometry(1, 1),
      cone: new THREE.ConeGeometry(1, 1, 8),
      cylinder: new THREE.CylinderGeometry(1, 1, 1, 12),
      disc: new THREE.CircleGeometry(1, 24),
      plane: new THREE.PlaneGeometry(1, 1),
    };
    this.materials = new Map();
    this.models = new Map();
    this.textures = new Set();
    this.projected = new THREE.Vector3();
    canvas.addEventListener('webglcontextlost', e => { e.preventDefault(); this.lost = true; });
    canvas.addEventListener('webglcontextrestored', () => { this.lost = false; });
  }

  resize(w, h, dpr) {
    this.w = w; this.h = h;
    this.renderer.setPixelRatio(Math.min(dpr, 1.5));
    this.renderer.setSize(w, h, false);
  }

  material(color) {
    if (!this.materials.has(color)) this.materials.set(color, new THREE.MeshLambertMaterial({
      color, flatShading: true, clippingPlanes: [this.clip],
    }));
    return this.materials.get(color);
  }

  part(group, shape, color, x, y, z, w, h, d) {
    const mesh = new THREE.Mesh(this.geometry[shape], this.material(color));
    mesh.position.set(x, y, z); mesh.scale.set(w, h, d);
    group.add(mesh);
    return mesh;
  }

  texture(canvas, dynamic = false) {
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    if (dynamic) { texture.generateMipmaps = false; texture.minFilter = THREE.LinearFilter; }
    this.textures.add(texture);
    return texture;
  }

  plane(texture, size, y) {
    const material = new THREE.MeshBasicMaterial({ map: texture, transparent: true, depthWrite: false });
    const mesh = new THREE.Mesh(this.geometry.plane, material);
    mesh.rotation.x = -Math.PI / 2; mesh.scale.set(size, size, 1); mesh.position.y = y;
    this.root.add(mesh);
    return mesh;
  }

  load(world) {
    if (this.root) {
      for (const batch of this.batches.values()) batch.dispose();
      this.batches.clear();
      this.scene.remove(this.root);
      const retained = new Set([...this.materials.values(), this.batchMaterial, this.shadowMaterial]);
      this.root.traverse(o => { if (o.material && !retained.has(o.material)) o.material.dispose(); });
      for (const t of this.textures) t.dispose();
      this.textures.clear(); this.models.clear();
    }
    this.world = world;
    this.root = new THREE.Group(); this.scene.add(this.root);
    const ground = document.createElement('canvas'); ground.width = ground.height = 2048;
    const ctx = ground.getContext('2d');
    const size = world.size + 400;
    ctx.scale(2048 / size, 2048 / size); ctx.translate(200, 200);
    drawGround(ctx, world, { x0: -200, y0: -200, x1: size, y1: size });
    const floor = this.plane(this.texture(ground), size, 0);
    floor.material.depthWrite = true; floor.material.transparent = false;
    floor.position.set(world.size / 2, 0, world.size / 2);
    this.effects = document.createElement('canvas'); this.effects.width = this.effects.height = 512;
    this.effectsTexture = this.texture(this.effects, true);
    this.effectPlane = this.plane(this.effectsTexture, 1, 0.7);
    this.effectPlane.renderOrder = 1;
    this.holeCanvas = document.createElement('canvas'); this.holeCanvas.width = this.holeCanvas.height = 256;
    this.holeTexture = this.texture(this.holeCanvas, true);
    this.holePlane = this.plane(this.holeTexture, 1, 0.9);
    this.holePlane.renderOrder = 2;
    this.lastEffects = this.lastHole = -Infinity;
  }

  model(o) {
    const group = new THREE.Group();
    const r = o.r, w = o.w || r * 1.5, d = o.h || r * 1.5;
    const color = o.color || '#eebc70';
    const p = (shape, c, x, y, z, a, b, csize) => this.part(group, shape, c, x, y, z, a, b, csize);
    const box = (c, x, y, z, a, b, csize) => p('box', c, x, y, z, a, b, csize);
    if (['house', 'building', 'tower', 'gas'].includes(o.kind)) {
      const h = (o.height || (o.kind === 'tower' ? 85 : 22)) * 2.3;
      box('#eee6cf', 0, h / 2, 0, w, h, d);
      box(color, 0, h + 3, 0, w * 1.07, 7, d * 1.07);
      if (o.kind === 'house') {
        const roof = p('cone', color, 0, h + w * 0.16, 0, w * 0.76, w * 0.32, d * 0.76);
        // Four-sided roof gives each house an unmistakable volumetric silhouette.
        roof.geometry = this.roofGeometry ||= new THREE.ConeGeometry(1, 1, 4);
        roof.rotation.y = Math.PI / 4;
      }
      for (let x = -w * 0.32; x <= w * 0.33; x += w * 0.32) {
        box('#506f88', x, h * 0.55, d / 2 + 0.5, w * 0.16, h * 0.35, 1);
      }
      box('#6e8084', w / 2 + 0.5, h * 0.55, 0, 1, h * 0.35, d * 0.55);
      box('#37495d', 0, h * 0.19, d / 2 + 1, w * 0.15, h * 0.38, 2);
      if (o.kind !== 'house') {
        for (let y = 12; y < h - 8; y += 18)
          box('#b8dce3', -w / 2 - 0.6, y, 0, 1.2, 7, d * 0.72);
      }
    } else if (['tree', 'palm', 'sakura', 'pine', 'cactus'].includes(o.kind)) {
      p('cylinder', '#97724e', 0, r * 0.7, 0, r * 0.15, r * 1.4, r * 0.15);
      p(o.kind === 'pine' ? 'cone' : 'ball', o.kind === 'sakura' ? '#ed9fc2' : '#63b887',
        0, r * 1.85, 0, r, r * 1.25, r);
    } else if (['car', 'truck', 'bus'].includes(o.kind)) {
      box(color, 0, 7, 0, w, 9, d);
      box('#a8dfe7', -w * 0.07, 14, 0, w * 0.5, 7, d * 0.85);
      for (const x of [-w * 0.3, w * 0.3]) for (const z of [-d * 0.5, d * 0.5])
        p('ball', '#33404e', x, 4, z, 4, 4, 2.5);
      box('#fff5c4', w / 2 + 0.2, 8, 0, 1, 3, d * 0.75);
    } else if (o.kind === 'fountain') {
      p('cylinder', '#d8e2df', 0, 3, 0, r, 6, r);
      p('cylinder', '#68cce3', 0, 6.5, 0, r * 0.85, 1, r * 0.85);
      p('cylinder', '#e2e6d3', 0, r * 0.65, 0, r * 0.16, r * 1.3, r * 0.16);
      p('ball', '#94e6f2', 0, r * 1.4, 0, r * 0.3, r * 0.4, r * 0.3);
    } else if (['sheep', 'panda', 'elephant', 'llama', 'camel'].includes(o.kind)) {
      const fur = o.kind === 'elephant' ? '#9bafba' : o.kind === 'camel' ? '#d1ac72' : '#f2ecd9';
      p('ball', fur, 0, r, 0, r, r * 0.7, r * 0.6);
      p('ball', o.kind === 'panda' ? '#36414f' : fur, r * 0.8, r * 1.45, 0, r * 0.5, r * 0.55, r * 0.5);
      for (const x of [-r * 0.6, r * 0.6]) for (const z of [-r * 0.4, r * 0.4])
        box('#6e7171', x, r * 0.35, z, r * 0.2, r * 0.7, r * 0.2);
    } else if (o.kind === 'person') {
      p('cylinder', color, 0, 8, 0, r * 0.55, 11, r * 0.55);
      p('ball', '#ffdab7', 0, 16, 0, r * 0.55, r * 0.55, r * 0.55);
      box('#334859', -2, 2, 0, 2.5, 5, 3); box('#334859', 2, 2, 0, 2.5, 5, 3);
    } else if (o.kind === 'bench') {
      box('#bc895c', 0, 6, 0, w, 3, d);
      box('#bc895c', 0, 11, -d * 0.4, w, 9, 2);
      for (const x of [-w * 0.35, w * 0.35]) box('#4d6270', x, 3, 0, 2, 6, d);
    } else if (['trash', 'hydrant', 'cone', 'pump', 'hay'].includes(o.kind)) {
      p(o.kind === 'cone' ? 'cone' : 'cylinder',
        { trash: '#6b9294', hydrant: '#ef7160', cone: '#ffa75b', pump: '#e35f69', hay: '#e8bf63' }[o.kind],
        0, r, 0, r * 0.7, r * 2, r * 0.7);
      p('cylinder', '#e9dfc5', 0, r * 1.7, 0, r * 0.75, r * 0.15, r * 0.75);
    } else {
      // Preserve every themed prop and boss until bespoke 3D models replace their artwork.
      const canvas = document.createElement('canvas'); canvas.width = canvas.height = o.isBoss ? 512 : 128;
      const ctx = canvas.getContext('2d'); const extent = r * 3.6;
      ctx.translate(canvas.width / 2, canvas.height / 2); ctx.scale(canvas.width / extent, canvas.height / extent);
      drawObject(ctx, { ...o, x: 0, y: 0, angle: 0 }, 0);
      const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.texture(canvas), depthWrite: false }));
      sprite.scale.set(extent, extent, 1); sprite.position.y = r * 0.85;
      group.add(sprite); group.userData.sprite = sprite;
      group.userData.context = ctx; group.userData.extent = extent;
    }
    const shadow = new THREE.Mesh(this.geometry.disc, this.shadowMaterial);
    shadow.rotation.x = -Math.PI / 2; shadow.position.set(r * 0.25, 0.5, r * 0.35); shadow.scale.set(r, r * 1.1, 1);
    group.add(shadow); group.userData.shadow = shadow;
    group.userData.parts = group.children.filter(part => part.isMesh);
    for (const part of group.userData.parts) {
      part.layers.set(1); // Only the pooled instance draws this part.
      part.updateMatrix(); part.matrixAutoUpdate = false;
    }
    this.root.add(group); this.models.set(o, group);
    return group;
  }

  submit(part) {
    const key = part.geometry.uuid;
    let batch = this.batches.get(key);
    if (!batch || batch.count === batch.instanceMatrix.count) {
      const capacity = batch ? batch.instanceMatrix.count * 2 : 256;
      const next = new THREE.InstancedMesh(part.geometry,
        part.material === this.shadowMaterial ? this.shadowMaterial : this.batchMaterial, capacity);
      next.count = batch?.count || 0;
      next.frustumCulled = false; // Instances are culled on the CPU before submission.
      next.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
      // Allocate colors before the first render, including empty batches.
      next.setColorAt(0, new THREE.Color('white'));
      next.instanceColor.setUsage(THREE.DynamicDrawUsage);
      if (batch) {
        next.instanceMatrix.array.set(batch.instanceMatrix.array);
        next.instanceColor.array.set(batch.instanceColor.array);
        this.root.remove(batch); batch.dispose();
      }
      this.root.add(next); this.batches.set(key, next); batch = next;
    }
    const index = batch.count++;
    batch.setMatrixAt(index, part.matrixWorld);
    batch.setColorAt(index, part.material === this.shadowMaterial ? this.white ||= new THREE.Color('white') : part.material.color);
  }

  project(x, z, height = 0) {
    this.projected.set(x, height, z).project(this.camera);
    return { x: (this.projected.x + 1) * this.w / 2, y: (1 - this.projected.y) * this.h / 2 };
  }

  render(game) {
    if (this.world !== game.world) this.load(game.world);
    const z = game.zoom, width = game.w / z, height = game.h / z;
    this.camera.left = -width / 2; this.camera.right = width / 2;
    this.camera.top = height / 2; this.camera.bottom = -height / 2;
    // No yaw: WASD and the touch joystick retain their familiar screen directions.
    const shake = game.fx.offset(game.time);
    const cx = game.cam.x - shake.x / z, cy = game.cam.y - shake.y / z;
    this.camera.position.set(cx, 2450, cy + 2800);
    this.camera.lookAt(cx, 0, cy); this.camera.updateProjectionMatrix(); this.camera.updateMatrixWorld();
    for (const batch of this.batches.values()) batch.count = 0;
    const reachX = width / 2 + 120, reachY = height / 2 / 0.658 + 200;
    for (const o of game.world.objects) {
      let model = this.models.get(o);
      const visible = !o.eaten && !o.hidden && Math.abs(o.x - cx) < reachX + o.r && Math.abs(o.y - cy) < reachY + o.r * 2;
      if (!visible) { if (model) model.visible = false; continue; }
      model ||= this.model(o); model.visible = true;
      const t = o.falling ? o.fallT : 0, scale = Math.max(0.001, 1 - t * t);
      model.position.set(o.falling ? o.fx + (game.hole.x - o.fx) * t : o.x,
        (o.lift || 0) - t * t * o.r * 3,
        o.falling ? o.fy + (game.hole.y - o.fy) * t : o.y);
      model.scale.setScalar(scale);
      model.rotation.set(t * (o.fallSpin || 1), -(o.angle || 0), t * 0.4);
      model.userData.shadow.visible = !o.falling;
      model.updateMatrixWorld(true);
      for (const part of model.userData.parts) if (part.visible) this.submit(part);
      if (o.isBoss && model.userData.sprite && game.time - (model.userData.lastArt ?? -Infinity) >= 1 / 15) {
        model.userData.lastArt = game.time;
        const ctx = model.userData.context, s = 512, extent = model.userData.extent;
        ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, s, s);
        ctx.translate(s / 2, s / 2); ctx.scale(s / extent, s / extent);
        drawObject(ctx, { ...o, x: 0, y: 0 }, game.time);
        model.userData.sprite.material.map.needsUpdate = true;
        model.userData.sprite.material.opacity = 1 - t;
      }
    }
    for (const batch of this.batches.values()) {
      batch.instanceMatrix.needsUpdate = true; batch.instanceColor.needsUpdate = true;
    }
    const h = game.hole;
    const holeSpan = h.r * 2.8;
    if (game.time - this.lastHole >= 1 / 30 || this.lastSkin !== game.look.skin) {
      const hc = this.holeCanvas.getContext('2d');
      hc.setTransform(1, 0, 0, 1, 0, 0); hc.clearRect(0, 0, 256, 256);
      hc.translate(128, 128); hc.scale(256 / holeSpan, 256 / holeSpan);
      drawSkinInside(hc, game.look.skin, 0, 0, h.r, game.time);
      drawSkinRim(hc, game.look.skin, 0, 0, h.r, game.time, h.pulse);
      this.holeTexture.needsUpdate = true; this.lastHole = game.time; this.lastSkin = game.look.skin;
    }
    this.holePlane.position.set(h.x, 0.9, h.y); this.holePlane.scale.set(holeSpan, holeSpan, 1);
    if (game.time - this.lastEffects >= 1 / 20) {
    this.lastEffects = game.time;
    const span = Math.max(width, height * 1.6) + 500;
    const ctx = this.effects.getContext('2d'), s = this.effects.width;
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, s, s);
    ctx.scale(s / span, s / span); ctx.translate(span / 2 - cx, span / 2 - cy);
    game.encounter?.draw(ctx);
    if (game.state === 'playing') game.behavior?.draw(ctx);
    drawParticles(ctx, game.particles, 0);
    drawParticles(ctx, game.particles, 1);
    game.fx.drawWorld(ctx, z); game.weather.drawWorld(ctx, z);
    for (const p of game.ripples || []) {
      ctx.save(); ctx.globalAlpha = Math.max(0, 1 - p.t / 0.55); ctx.strokeStyle = '#fff0a0'; ctx.lineWidth = 3 / z;
      ctx.beginPath(); ctx.arc(p.x, p.y, p.r * (1 + p.t * 1.4), 0, Math.PI * 2); ctx.stroke(); ctx.restore();
    }
    this.effectPlane.position.set(cx, 0.7, cy); this.effectPlane.scale.set(span, span, 1);
    this.effectsTexture.needsUpdate = true;
    }
    this.renderer.render(this.scene, this.camera);
  }
}
