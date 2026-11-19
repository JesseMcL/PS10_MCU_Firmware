// PS10 radar gates: a live chart of the LD2410's per-gate energies and
// thresholds on the device's own web page (web_server js_include).
//
// It reads the device log over the page's event stream: in engineering mode
// ps10-mcu.yaml logs, under the ps10_gates tag,
//   E m=<9 moving energies> s=<9 still energies>   5 times a second
//   T m=<9 moving thresholds> s=<9 still thresholds> r=<max moving gate>,<max still gate>,<hold s>   every 2 s
//   C <calibration progress>
// Nothing here goes to Home Assistant. Bars are the current energy, the thin
// tick above each bar its peak since "Reset peaks", the line across each bar
// its threshold: a gate detects when its bar crosses its line. Gates beyond
// the moving or still range are faded: the radar ignores them for that kind.
(() => {
  const GATES = 9;
  const GATE_M = 0.75;   // metres per gate at the default resolution
  const LINE = /\[ps10_gates[^\]]*\]:\s*([ETC]) (.*)$/;
  const ANSI = /\x1b\[[0-9;]*m/g;

  const st = {
    m: Array(GATES).fill(null), s: Array(GATES).fill(null),
    pm: Array(GATES).fill(0), ps: Array(GATES).fill(0),
    tm: Array(GATES).fill(null), ts: Array(GATES).fill(null), range: null,
    last: 0, cal: [],
  };

  const css = `
    #ps10g { font: 14px system-ui, sans-serif; margin: 16px auto; max-width: 900px; padding: 0 16px; color: var(--g-fg); }
    #ps10g { --g-fg: #1d2330; --g-dim: #6b7280; --g-grid: #e3e6ea; --g-move: #2f6fd6; --g-still: #d98a1c; --g-th: #c0262d; --g-bg: #fff; }
    @media (prefers-color-scheme: dark) {
      #ps10g { --g-fg: #e6e8eb; --g-dim: #9aa3ae; --g-grid: #343a43; --g-move: #5b93f0; --g-still: #f0a742; --g-th: #f0555b; --g-bg: #1b1f24; }
    }
    #ps10g h3 { margin: 0 0 4px; font-size: 16px; }
    #ps10g .bar { display: flex; flex-wrap: wrap; gap: 12px; align-items: center; margin: 6px 0; color: var(--g-dim); }
    #ps10g .key { display: inline-flex; align-items: center; gap: 4px; }
    #ps10g .sw { width: 12px; height: 12px; border-radius: 2px; display: inline-block; }
    #ps10g canvas { width: 100%; height: 280px; display: block; background: var(--g-bg); border-radius: 6px; }
    #ps10g button { font: inherit; padding: 4px 10px; border-radius: 4px; border: 1px solid var(--g-grid); background: transparent; color: var(--g-fg); cursor: pointer; }
    #ps10g pre { margin: 6px 0 0; font: 12px ui-monospace, monospace; color: var(--g-dim); white-space: pre-wrap; }`;

  const box = document.createElement('section');
  box.id = 'ps10g';
  box.innerHTML = `<style>${css}</style>
    <h3>Radar gates</h3>
    <div class="bar">
      <span class="key"><span class="sw" style="background:var(--g-move)"></span>moving</span>
      <span class="key"><span class="sw" style="background:var(--g-still)"></span>still</span>
      <span class="key"><span class="sw" style="background:var(--g-th);height:2px"></span>threshold</span>
      <span class="key">▔ peak</span>
      <button type="button">Reset peaks</button>
      <span class="status"></span>
    </div>
    <canvas></canvas>
    <div class="bar range"></div>
    <pre></pre>`;
  const canvas = box.querySelector('canvas');
  const status = box.querySelector('.status');
  const calLog = box.querySelector('pre');
  const rangeText = box.querySelector('.range');
  box.querySelector('button').onclick = () => { st.pm.fill(0); st.ps.fill(0); dirty = true; };

  const list = (text, key) => {
    const m = text.match(new RegExp(key + '=([-\\d,]+)'));
    return m ? m[1].split(',').map(v => (v === '-' ? null : Number(v))) : null;
  };

  let dirty = true;
  function onLine(raw) {
    const m = String(raw).replace(ANSI, '').match(LINE);
    if (!m) return;
    const [, kind, text] = m;
    if (kind === 'E') {
      const mv = list(text, 'm'), sv = list(text, 's');
      if (!mv || !sv) return;
      st.m = mv; st.s = sv; st.last = Date.now();
      mv.forEach((v, i) => { if (v != null && v <= 100) st.pm[i] = Math.max(st.pm[i], v); });
      sv.forEach((v, i) => { if (v != null && v <= 100) st.ps[i] = Math.max(st.ps[i], v); });
    } else if (kind === 'T') {
      st.tm = list(text, 'm') || st.tm; st.ts = list(text, 's') || st.ts;
      const r = list(text, 'r');
      if (r && r[0] >= 0 && r[1] >= 0) {
        st.range = r;
        rangeText.textContent = `Moving range ${(r[0] * GATE_M).toFixed(2)} m (g${r[0]}), still range ${(r[1] * GATE_M).toFixed(2)} m (g${r[1]})` +
          (r[2] >= 0 ? `, hold ${r[2]} s after the last detection` : '');
      }
    } else {
      st.cal.push(new Date().toLocaleTimeString() + '  ' + text);
      st.cal = st.cal.slice(-6);
      calLog.textContent = st.cal.join('\n');
    }
    dirty = true;
  }

  function draw() {
    requestAnimationFrame(draw);
    const live = Date.now() - st.last < 2000;
    status.textContent = live ? '' : 'Waiting for data: turn on "Radar engineering mode".';
    if (!dirty) return;
    dirty = false;
    const dpr = window.devicePixelRatio || 1;
    const w = canvas.clientWidth, h = canvas.clientHeight;
    if (canvas.width !== w * dpr || canvas.height !== h * dpr) { canvas.width = w * dpr; canvas.height = h * dpr; }
    const g = canvas.getContext('2d');
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, w, h);
    const cs = getComputedStyle(box);
    const col = n => cs.getPropertyValue('--g-' + n).trim();
    const L = 34, R = 8, T = 10, B = 36, pw = w - L - R, ph = h - T - B;
    const y = v => T + ph - (Math.max(0, Math.min(100, v)) / 100) * ph;

    g.font = '11px system-ui, sans-serif';
    g.textAlign = 'right'; g.textBaseline = 'middle';
    for (let v = 0; v <= 100; v += 25) {
      g.strokeStyle = col('grid'); g.lineWidth = 1;
      g.beginPath(); g.moveTo(L, Math.round(y(v)) + 0.5); g.lineTo(L + pw, Math.round(y(v)) + 0.5); g.stroke();
      g.fillStyle = col('dim'); g.fillText(v, L - 6, y(v));
    }

    const gw = pw / GATES, bw = Math.min(26, gw * 0.32), gap = 3;
    g.textAlign = 'center'; g.textBaseline = 'top';
    for (let i = 0; i < GATES; i++) {
      const cx = L + gw * i + gw / 2;
      [['move', st.m[i], st.pm[i], st.tm[i], cx - bw - gap / 2, st.range && i > st.range[0]],
       ['still', st.s[i], st.ps[i], st.ts[i], cx + gap / 2, st.range && i > st.range[1]]].forEach(([c, v, peak, th, x, out]) => {
        g.globalAlpha = out ? 0.2 : 1;
        if (live && v != null) {
          g.fillStyle = col(c);
          g.fillRect(x, y(v), bw, y(0) - y(v));
        }
        if (peak > 0) {
          g.fillStyle = col(c);
          g.fillRect(x, Math.round(y(peak)) - 1, bw, 2);
        }
        if (th != null) {
          g.fillStyle = col('th');
          g.fillRect(x - 2, Math.round(y(th)) - 1, bw + 4, 2);
        }
        g.globalAlpha = 1;
      });
      g.fillStyle = col('fg'); g.fillText('g' + i, cx, T + ph + 6);
      g.fillStyle = col('dim'); g.fillText((i * GATE_M).toFixed(2) + ' m', cx, T + ph + 20);
    }
  }

  const start = () => {
    document.body.appendChild(box);
    const es = new EventSource('/events');
    es.addEventListener('log', e => onLine(e.data));
    window.addEventListener('resize', () => { dirty = true; });
    requestAnimationFrame(draw);
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
