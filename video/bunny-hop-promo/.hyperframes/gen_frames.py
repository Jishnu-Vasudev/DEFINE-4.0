"""Generates compositions/frames/NN-*.html for the Bunny Hop promo from one shared design.

Each frame is a bare <template> sub-composition: scoped CSS (prefixed .fNN), local @font-face,
a full-duration background clip, one content clip, and one paused GSAP timeline registered at
window.__timelines["<frame_id>"]. Reveals are timed to the frame's narration (durations from
STORYBOARD.md, synced to the recorded voice). Re-run after editing: python .hyperframes/gen_frames.py
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SB = open(os.path.join(ROOT, 'STORYBOARD.md'), encoding='utf-8').read()
DUR = {}
for m in re.finditer(r'## Frame (\d+) .*?- duration: ([\d.]+)s.*?- src: (compositions/frames/([\w-]+)\.html)', SB, re.S):
    DUR[int(m.group(1))] = (float(m.group(2)), m.group(4))

FONTS = ''.join(
    f'@font-face{{font-family:"Barlow";src:url(assets/fonts/barlow-latin-{w}-normal.woff2) format("woff2");font-weight:{w}}}'
    for w in (400, 600, 700, 800, 900)
) + '@font-face{font-family:"IBM Plex Mono";src:url(assets/fonts/ibm-plex-mono-latin-500-normal.woff2) format("woff2");font-weight:500}'

# shared look, scoped per frame with {P} (the .fNN class)
CSS = """
#root{position:absolute;inset:0;overflow:hidden;font-family:Barlow,sans-serif;color:#FFF6EA}
{P}.clip{position:absolute;inset:0}
{P}.bg{background:radial-gradient(1150px 760px at 76% -12%,rgba(232,93,24,.30),rgba(232,93,24,0) 62%),#1B110B}
{P}.bg.orange{background:#E85D18}
{P} .layer{position:absolute;inset:0}
{P} .kicker{position:absolute;font-family:"IBM Plex Mono",monospace;font-weight:500;font-size:20px;letter-spacing:.14em;text-transform:uppercase;color:#E85D18}
{P} .display{font-weight:900;font-size:176px;line-height:.88;letter-spacing:-.04em;text-transform:lowercase}
{P} .h1{font-weight:800;font-size:112px;line-height:.92;letter-spacing:-.03em;text-transform:lowercase}
{P} .h2{font-weight:700;font-size:66px;line-height:1.06;letter-spacing:-.02em;text-transform:lowercase}
{P} .ember{color:#E85D18}{P} .amber{color:#FF9A3D}{P} .muted{color:#C4AA94}{P} .hint{color:#5c4d43}
{P} .stack{position:absolute;display:flex;flex-direction:column;gap:14px}
{P} .word{display:block}
{P} .phone{position:absolute;width:350px;height:740px;border-radius:58px;background:#0e0806;border:7px solid #3a2a20;box-shadow:0 40px 90px rgba(0,0,0,.6),0 0 80px rgba(232,93,24,.20);overflow:hidden}
{P} .scr{position:absolute;inset:10px;border-radius:48px;background:#1B110B;overflow:hidden;padding:52px 22px 20px}
{P} .notch{position:absolute;top:18px;left:50%;width:90px;height:22px;margin-left:-45px;border-radius:20px;background:#000;z-index:3}
{P} .ptitle{font-weight:700;font-size:25px;text-align:center}
{P} .psub{font-size:14px;color:#C4AA94;text-align:center;line-height:1.35}
{P} .field{background:#342216;border:1px solid #4a3223;border-radius:16px;padding:12px 16px;font-size:16px;color:#C4AA94;margin-top:12px}
{P} .field b{color:#FFF6EA;font-weight:600}
{P} .btn{background:#FF9A3D;color:#2a1105;border-radius:18px;padding:15px;font-weight:700;font-size:17px;text-align:center;margin-top:14px;position:relative}
{P} .card{background:rgba(52,34,22,.92);border:1px solid rgba(255,224,184,.14);border-radius:20px;padding:14px;display:flex;gap:12px;align-items:center;margin-top:12px}
{P} .ic{width:44px;height:44px;border-radius:14px;background:linear-gradient(135deg,#FF9A3D,#E85D18);flex:none}
{P} .ct{font-weight:700;font-size:18px}{P} .cs{font-size:13px;color:#C4AA94}
{P} .bubble{max-width:78%;border-radius:18px;padding:10px 14px;font-size:15px;margin-top:10px;background:#342216}
{P} .bubble.me{margin-left:auto;background:#6a3415}
{P} .ptt{position:absolute;left:18px;right:18px;bottom:26px;height:66px;border-radius:40px;background:#342216;border:1.5px solid #4a3223;display:flex;align-items:center;gap:12px;padding:0 9px;font-weight:800;font-size:16px}
{P} .orb{width:50px;height:50px;border-radius:50%;background:rgba(255,154,61,.16);flex:none}
{P} .tap{position:absolute;width:64px;height:64px;border-radius:50%;border:5px solid rgba(255,246,234,.95);box-shadow:0 0 0 18px rgba(255,246,234,.16)}
{P} .redbar{background:rgba(255,93,79,.18);color:#FF5D4F;font-weight:700;font-size:13px;padding:8px 10px;border-radius:10px}
{P} .wave{display:flex;gap:5px;align-items:center;justify-content:center}
{P} .wave i{display:block;width:8px;border-radius:5px;background:#FF9A3D}
{P} .dash{position:absolute;border-radius:24px;background:#1f140d;border:1px solid rgba(255,224,184,.14);box-shadow:0 40px 90px rgba(0,0,0,.55);overflow:hidden}
{P} .dbar{display:flex;align-items:center;gap:22px;padding:22px 30px;border-bottom:1px solid rgba(255,224,184,.12);font-size:28px}
{P} .dbar b{font-weight:700}
{P} .pill{font-size:19px;padding:6px 16px;border-radius:40px;border:1px solid rgba(255,224,184,.2);color:#C4AA94;white-space:nowrap}
{P} .row{display:flex;gap:18px;align-items:flex-start;padding:16px 0;border-top:1px solid rgba(255,224,184,.1);font-size:23px;line-height:1.35}
{P} .av{width:46px;height:46px;border-radius:50%;background:linear-gradient(135deg,#6a3415,#a24a1c);flex:none}
{P} .badge{display:inline-block;font-size:17px;padding:2px 12px;border-radius:40px;border:1px solid rgba(255,154,61,.5);color:#FF9A3D;vertical-align:middle}
{P} .node{border-radius:12px;background:rgba(255,154,61,.55)}
{P} .mono{font-family:"IBM Plex Mono",monospace;font-weight:500}
{P} .glowdot{position:absolute;border-radius:50%;background:radial-gradient(circle,rgba(232,93,24,.55),rgba(232,93,24,0) 70%)}
"""


def chars(text, cls, prefix):
    """Text split into per-character spans for seek-safe typing (revealed by a stagger)."""
    out = []
    for c in text:
        out.append(f'<span class="{prefix}-ch">{"&nbsp;" if c == " " else c}</span>')
    return f'<span class="{cls}">' + ''.join(out) + '</span>'


def wave(n, h=46, seed=3):
    hs = [(seed * 37 + i * 53) % 90 + 10 for i in range(n)]
    return '<div class="wave">' + ''.join(f'<i style="height:{int(h * v / 100)}px"></i>' for v in hs) + '</div>'


def frame(num, body, js, orange=False):
    dur, fid = DUR[num]
    P = f'.f{num:02d}'
    css = FONTS + CSS.replace('{P}', P)
    return f"""<template>
<style>{css}</style>
<div id="root" data-composition-id="{fid}" data-start="0" data-width="1920" data-height="1080" data-duration="{dur}">
  <div id="f{num:02d}-bg" class="clip bg{' orange' if orange else ''} f{num:02d}" data-start="0" data-duration="{dur}" data-track-index="0"></div>
  <div id="f{num:02d}-content" class="clip f{num:02d}" data-start="0" data-duration="{dur}" data-track-index="1">
    <div class="layer" id="f{num:02d}-cam">
{body}
    </div>
  </div>
</div>
<script>
(function(){{
  const tl = gsap.timeline({{ paused: true }});
  const q = (s) => document.querySelectorAll('[data-composition-id="{fid}"] ' + s);
  const D = {dur};
{js}
  window.__timelines["{fid}"] = tl;
}})();
</script>
</template>
"""


def type_in(sel, at, per=0.045):
    return f"  tl.fromTo(q('{sel} .{sel.strip('#.')}-ch'), {{opacity:0}}, {{opacity:1, duration:0.01, stagger:{per}, ease:'none'}}, {at});\n"


F = {}

# 01 hook: kinetic lines, "silent" drains, "not yours." slams
F[1] = ("""      <div class="stack" style="left:110px;top:150px;width:1300px">
        <div class="h2 word" id="f01-a">big event.</div>
        <div class="h2 word" id="f01-b">hundreds of staff.</div>
        <div class="h2 word" id="f01-c">the wi-fi drops, and the team goes <span id="f01-silent">silent.</span></div>
      </div>
      <div class="glowdot" id="f01-glow" style="left:1080px;top:420px;width:900px;height:520px"></div>
      <div class="display ember" id="f01-not" style="position:absolute;right:110px;top:600px">not yours.</div>""",
"""  tl.fromTo('#f01-a', {y:40, opacity:0}, {y:0, opacity:1, duration:0.5, ease:'power3.out'}, 0.1);
  tl.fromTo('#f01-b', {y:40, opacity:0}, {y:0, opacity:1, duration:0.5, ease:'power3.out'}, 1.2);
  tl.to('#f01-a', {color:'#9a8c82', duration:0.5}, 1.2);
  tl.fromTo('#f01-c', {y:40, opacity:0}, {y:0, opacity:1, duration:0.55, ease:'power3.out'}, 2.3);
  tl.to('#f01-b', {color:'#9a8c82', duration:0.5}, 2.4);
  tl.to('#f01-silent', {color:'#9a8c82', duration:0.9, ease:'power2.inOut'}, 3.6);
  tl.to(['#f01-a','#f01-b','#f01-c'], {opacity:0.85, duration:0.6}, 4.3);
  tl.fromTo('#f01-glow', {opacity:0, scale:0.6}, {opacity:1, scale:1, duration:0.9, ease:'power3.out'}, 4.4);
  tl.fromTo('#f01-not', {opacity:0, scale:1.35, y:-20}, {opacity:1, scale:1, y:0, duration:0.45, ease:'power4.out'}, 4.45);
  tl.fromTo('#f01-cam', {scale:1}, {scale:1.04, duration:D, ease:'none', transformOrigin:'50% 50%'}, 0);
""")

# 02 lockup
F[2] = ("""      <div class="glowdot" id="f02-glow" style="left:660px;top:40px;width:600px;height:600px"></div>
      <div style="position:absolute;left:0;right:0;top:120px;display:flex;flex-direction:column;align-items:center">
        <div style="position:relative;width:300px;height:300px">
          <svg id="f02-ring" width="300" height="300" viewBox="0 0 300 300" style="position:absolute;inset:0"><circle cx="150" cy="150" r="144" fill="none" stroke="#E85D18" stroke-width="3" stroke-dasharray="905" stroke-dashoffset="905" transform="rotate(-90 150 150)"/></svg>
          <img id="f02-logo" src="assets/logo.png" alt="" style="position:absolute;left:18px;top:18px;width:264px;height:264px;border-radius:50%">
        </div>
        <div class="display" id="f02-word" style="margin-top:40px;font-size:150px">""" + ''.join(f'<span class="f02-l" style="display:inline-block">{c if c != " " else "&nbsp;"}</span>' for c in "bunny hop") + """</div>
        <div class="kicker" style="position:relative;margin-top:22px;color:#FF9A3D;font-size:24px">""" + chars("your whole team, one press away", "f02-tag", "f02-tag") + """</div>
      </div>""",
"""  tl.to('#f02-ring circle', {strokeDashoffset:0, duration:0.9, ease:'power2.inOut'}, 0);
  tl.fromTo('#f02-glow', {opacity:0, scale:0.5}, {opacity:1, scale:1, duration:1.0, ease:'power3.out'}, 0.1);
  tl.fromTo('#f02-logo', {scale:0.6, opacity:0}, {scale:1, opacity:1, duration:0.7, ease:'back.out(1.6)'}, 0.25);
  tl.fromTo(q('.f02-l'), {y:70, opacity:0}, {y:0, opacity:1, duration:0.5, stagger:0.05, ease:'power3.out'}, 1.05);
""" + type_in('.f02-tag', 2.05, 0.03))

# 03 join: phone scale-in, typing, finger tap
PHONE3 = """<div class="phone" id="f03-phone" style="left:1180px;top:110px"><div class="notch"></div><div class="scr">
          <div id="f03-join">
            <div style="position:relative;height:150px;margin-top:6px">
              <div id="f03-r1" style="position:absolute;left:50%;top:50%;width:210px;height:210px;margin:-105px 0 0 -105px;border-radius:50%;border:2px solid rgba(255,154,61,.5)"></div>
              <div id="f03-r2" style="position:absolute;left:50%;top:50%;width:210px;height:210px;margin:-105px 0 0 -105px;border-radius:50%;border:2px solid rgba(255,154,61,.5)"></div>
              <img src="assets/logo.png" alt="" style="position:absolute;left:50%;top:50%;width:112px;height:112px;margin:-56px 0 0 -56px;border-radius:50%">
            </div>
            <div class="ptitle" style="margin-top:26px">Join a channel</div>
            <div class="psub" style="margin-top:6px">Scan the channel QR from your admin, or type its code.</div>
            <div class="field">Your name&nbsp;&nbsp;<b>""" + chars("Asha", "f03-name", "f03-name") + """</b><span class="amber">|</span></div>
            <div class="btn" id="f03-btn">Scan channel QR<span class="tap" id="f03-tap" style="right:60px;top:-4px"></span></div>
            <div class="psub" style="margin-top:14px">or enter the code</div>
          </div>
          <div id="f03-done" style="position:absolute;left:22px;right:22px;top:300px;opacity:0">
            <div class="card" style="border-color:rgba(255,154,61,.7)"><span class="ic"></span><span><div class="ct">Gate B</div><div class="cs amber">Joined · encrypted</div></span></div>
          </div>
        </div></div>"""
F[3] = (f"""      <div class="kicker" style="left:110px;top:150px">01 · join</div>
      <div class="stack" style="left:110px;top:200px">
        <div class="h1 word" id="f03-s1">scan.</div>
        <div class="h1 word" id="f03-s2">type.</div>
        <div class="h1 word ember" id="f03-s3">tap.</div>
      </div>
      {PHONE3}""",
"""  tl.fromTo('#f03-phone', {scale:0.7, opacity:0, y:40}, {scale:1, opacity:1, y:0, duration:1.0, ease:'power2.out'}, 0);
  tl.fromTo(['#f03-r1','#f03-r2'], {scale:0.55, opacity:0.9}, {scale:1.25, opacity:0, duration:1.6, ease:'power1.out', stagger:0.8}, 0.3);
  tl.fromTo('#f03-s1', {x:-40, opacity:0}, {x:0, opacity:1, duration:0.45, ease:'power3.out'}, 0.2);
  tl.fromTo('#f03-s2', {x:-40, opacity:0}, {x:0, opacity:1, duration:0.45, ease:'power3.out'}, 1.45);
""" + type_in('.f03-name', 1.6, 0.12) + """  tl.fromTo('#f03-s3', {x:-40, opacity:0}, {x:0, opacity:1, duration:0.45, ease:'power3.out'}, 2.75);
  tl.fromTo('#f03-tap', {scale:0.3, opacity:0}, {scale:1.15, opacity:1, duration:0.25, ease:'power2.out'}, 2.8);
  tl.to('#f03-tap', {scale:1.6, opacity:0, duration:0.4, ease:'power2.out'}, 3.05);
  tl.fromTo('#f03-btn', {scale:1}, {scale:0.95, duration:0.12, yoyo:true, repeat:1, ease:'power1.inOut', immediateRender:false}, 2.85);
  tl.to('#f03-join', {x:-330, opacity:0, duration:0.55, ease:'power2.inOut'}, 3.6);
  tl.fromTo('#f03-done', {x:330, opacity:0}, {x:0, opacity:1, duration:0.55, ease:'power2.inOut'}, 3.6);
""")

# 04 channels
F[4] = ("""      <div class="kicker" style="left:110px;top:150px">02 · channels</div>
      <div class="stack" style="left:110px;top:200px">
        <div class="h1 word" id="f04-a">every crew.</div>
        <div class="h1 word" id="f04-b">every zone.</div>
      </div>
      <div class="phone" style="left:1180px;top:110px"><div class="notch"></div><div class="scr">
        <div class="ptitle">Channels</div><div class="psub">3 channels</div>
        <div style="font-weight:700;font-size:21px;margin-top:22px">Hi, Asha</div>
        <div class="card" id="f04-c1"><span class="ic"></span><span><div class="ct">Gate B</div><div class="cs">Ravi: queue is moving</div></span></div>
        <div class="card" id="f04-c2"><span class="ic"></span><span><div class="ct">Medical</div><div class="cs">Team channel</div></span></div>
        <div class="card" id="f04-c3"><span class="ic"></span><span><div class="ct">Stage Crew</div><div class="cs">Zone channel</div></span></div>
      </div></div>""",
"""  tl.fromTo('#f04-a', {y:40, opacity:0}, {y:0, opacity:1, duration:0.5, ease:'power3.out'}, 0.1);
  tl.fromTo(['#f04-c1','#f04-c2','#f04-c3'], {y:50, opacity:0}, {y:0, opacity:1, duration:0.5, stagger:0.35, ease:'power3.out'}, 0.7);
  tl.fromTo('#f04-b', {y:40, opacity:0}, {y:0, opacity:1, duration:0.5, ease:'power3.out'}, 1.25);
  tl.to('#f04-c1', {borderColor:'rgba(255,154,61,.85)', boxShadow:'0 0 34px rgba(232,93,24,.45)', duration:0.5}, 2.3);
""")

# 05 push to talk
F[5] = ("""      <div class="kicker" style="left:110px;top:150px">03 · push to talk</div>
      <div class="stack" style="left:110px;top:200px"><div class="h1 word" id="f05-h">hold<br>to <span class="ember">talk.</span></div></div>
      <div class="phone" id="f05-p1" style="left:820px;top:110px"><div class="notch"></div><div class="scr">
        <div class="ptitle">Gate B</div><div class="psub amber">Encrypted</div>
        <div id="f05-wv" style="margin-top:150px;opacity:0">""" + wave(18, 120, 5) + """</div>
        <div class="ptt" id="f05-ptt"><span class="orb" id="f05-orb"></span><span id="f05-l1">Hold to talk</span><span id="f05-l2" style="position:absolute;left:80px;opacity:0;color:#2a1105">Talking… release to stop</span></div>
        <span class="tap" id="f05-tap" style="left:30px;bottom:27px;opacity:0"></span>
      </div></div>
      <div class="phone" id="f05-p2" style="left:1300px;top:200px;transform-origin:50% 50%"><div class="notch"></div><div class="scr">
        <div class="ptitle">Gate B</div><div class="psub">3 online</div>
        <div class="card" style="border-color:rgba(255,154,61,.75);margin-top:40px"><span class="ic"></span><span><div class="ct amber">Asha is talking</div><div style="margin-top:6px">""" + wave(10, 26, 7) + """</div></span></div>
      </div></div>
      <div id="f05-lock" style="position:absolute;left:1300px;top:120px;padding:12px 22px;border-radius:40px;background:#342216;border:1px solid rgba(255,154,61,.6);font-size:22px;font-weight:700;color:#FF9A3D">🔒 volume key = talk</div>""",
"""  tl.fromTo('#f05-h', {y:40, opacity:0}, {y:0, opacity:1, duration:0.5, ease:'power3.out'}, 0.1);
  tl.fromTo('#f05-p1', {y:50, opacity:0}, {y:0, opacity:1, duration:0.7, ease:'power3.out'}, 0);
  tl.fromTo('#f05-tap', {scale:0.3, opacity:0}, {scale:1.1, opacity:1, duration:0.25}, 1.4);
  tl.to('#f05-tap', {scale:1.7, opacity:0, duration:0.4}, 1.65);
  tl.to('#f05-ptt', {background:'linear-gradient(90deg,#FF9A3D,#E85D18)', borderColor:'#FF9A3D', boxShadow:'0 0 44px rgba(232,93,24,.6)', duration:0.35}, 1.5);
  tl.to('#f05-l1', {opacity:0, duration:0.2}, 1.5);
  tl.to('#f05-l2', {opacity:1, duration:0.25}, 1.6);
  tl.to('#f05-orb', {background:'rgba(255,255,255,.35)', duration:0.3}, 1.5);
  tl.fromTo('#f05-orb', {scale:1}, {scale:1.15, duration:0.45, ease:'sine.inOut', yoyo:true, repeat:9}, 1.8);
  tl.to('#f05-wv', {opacity:1, duration:0.4}, 1.7);
  tl.fromTo(q('#f05-wv i'), {scaleY:0.3}, {scaleY:1, duration:0.3, stagger:{each:0.05, from:'center'}, ease:'sine.inOut', yoyo:true, repeat:11}, 1.8);
  tl.fromTo('#f05-p2', {x:260, opacity:0}, {x:0, opacity:1, duration:0.7, ease:'power2.out'}, 3.0);
  tl.fromTo('#f05-lock', {scale:0.6, opacity:0}, {scale:1, opacity:1, duration:0.45, ease:'back.out(1.7)'}, 4.8);
""")

# 06 more than voice
F[6] = ("""      <div class="kicker" style="left:110px;top:150px">04 · more than voice</div>
      <div class="stack" style="left:110px;top:200px;gap:8px">
        <div class="h2 word hint" id="f06-w1">messages.</div><div class="h2 word hint" id="f06-w2">photos.</div>
        <div class="h2 word hint" id="f06-w3">voice notes.</div><div class="h2 word hint" id="f06-w4">files.</div>
      </div>
      <div class="phone" style="left:1180px;top:110px"><div class="notch"></div><div class="scr">
        <div class="ptitle">Gate B</div><div class="psub amber">Encrypted</div>
        <div class="bubble" id="f06-b1" style="margin-top:22px">Need water at Gate B</div>
        <div class="bubble me" id="f06-b2" style="height:150px;background:linear-gradient(135deg,#8a5a34,#3a2418)"><span class="cs" style="color:#FFF6EA">photo · queue at gate</span></div>
        <div class="bubble" id="f06-b3"><div style="display:flex;align-items:center;gap:10px"><span class="amber">▶</span>""" + wave(12, 24, 2) + """<span class="cs">0:07</span></div></div>
        <div class="bubble me" id="f06-b4">📄 floor-plan.pdf</div>
      </div></div>""",
"""  const lit = (sel, at, c) => tl.to(sel, {color:c || '#FFF6EA', duration:0.3}, at);
  [['#f06-w1','#f06-b1',0.05],['#f06-w2','#f06-b2',1.0],['#f06-w3','#f06-b3',1.9],['#f06-w4','#f06-b4',2.9]].forEach(([w,b,t],i)=>{
    tl.fromTo(b, {y:40, opacity:0, scale:0.95}, {y:0, opacity:1, scale:1, duration:0.45, ease:'power3.out'}, t);
    lit(w, t, i===3 ? '#E85D18' : '#FFF6EA');
  });
""")

# 07 e2ee scramble
F[7] = ("""      <div style="position:absolute;left:0;right:0;top:170px;display:flex;justify-content:center;align-items:center;gap:60px">
        <div class="mono" id="f07-a" style="font-size:30px;padding:20px 30px;border-radius:20px;background:#342216">need water at gate b</div>
        <div id="f07-srv" style="width:260px;height:150px;border-radius:22px;border:2px solid rgba(255,154,61,.5);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px">
          <span class="mono" style="font-size:16px;letter-spacing:.14em;color:#C4AA94">SERVER</span>
          <span class="mono ember" id="f07-x" style="font-size:30px;opacity:0">9f#k2Q!x…</span></div>
        <div class="mono" id="f07-b" style="font-size:30px;padding:20px 30px;border-radius:20px;background:#6a3415;opacity:0">need water at gate b</div>
      </div>
      <div class="h1" id="f07-h" style="position:absolute;left:0;right:0;top:470px;text-align:center">not even the server<br><span class="ember">can read it.</span></div>""",
"""  tl.fromTo('#f07-a', {x:-60, opacity:0}, {x:0, opacity:1, duration:0.5, ease:'power3.out'}, 0.05);
  tl.fromTo('#f07-srv', {scale:0.85, opacity:0}, {scale:1, opacity:1, duration:0.5, ease:'power3.out'}, 0.4);
  tl.to('#f07-a', {opacity:0.35, duration:0.3}, 1.4);
  tl.to('#f07-x', {opacity:1, duration:0.2}, 1.45);
  tl.fromTo('#f07-x', {x:-40}, {x:0, duration:0.6, ease:'power2.out'}, 1.45);
  tl.to('#f07-x', {opacity:0.25, duration:0.3}, 2.5);
  tl.fromTo('#f07-b', {x:-40, opacity:0}, {x:0, opacity:1, duration:0.45, ease:'power3.out'}, 2.55);
  tl.fromTo('#f07-h', {y:50, opacity:0}, {y:0, opacity:1, duration:0.6, ease:'power3.out'}, 2.7);
  tl.fromTo('#f07-cam', {scale:1.08}, {scale:1, duration:D, ease:'power2.out', transformOrigin:'50% 40%'}, 0);
""")

# 08 mesh
def mini_phone(fid, x, y, inner):
    return f"""<div class="phone" id="{fid}" style="left:{x}px;top:{y}px;width:250px;height:520px;border-radius:44px"><div class="notch" style="width:70px;margin-left:-35px"></div><div class="scr" style="border-radius:36px;padding:44px 16px 16px">{inner}</div></div>"""
F[8] = ("""      <div class="kicker" style="left:110px;top:110px;color:#FF5D4F">05 · no wi-fi</div>
      <div class="h2" style="position:absolute;left:110px;top:150px"><span id="f08-h1">wi-fi dies.</span> <span class="ember" id="f08-h2">bunny hop doesn't.</span></div>
      <div id="f08-wifi" style="position:absolute;left:1580px;top:120px;font-size:64px;color:#C4AA94">📶<span id="f08-x" style="position:absolute;left:30px;top:-8px;color:#FF5D4F;opacity:0">✕</span></div>
      """ + mini_phone('f08-p1', 230, 300, '<div class="redbar f08-rb">Server lost: nearby mode</div><div class="bubble me" id="f08-m1" style="font-size:14px">On my way</div>')
        + mini_phone('f08-p2', 835, 360, '<div class="redbar f08-rb">Server lost: nearby mode</div><div class="bubble" id="f08-m2" style="font-size:14px;opacity:0">On my way</div>')
        + mini_phone('f08-p3', 1440, 300, '<div class="redbar f08-rb">Server lost: nearby mode</div><div class="bubble" id="f08-m3" style="font-size:14px;opacity:0">On my way</div>') + """
      <svg style="position:absolute;inset:0" width="1920" height="1080"><path id="f08-l1" d="M480 560 Q660 470 835 600" stroke="#FF9A3D" stroke-width="4" stroke-dasharray="12 12" fill="none" opacity="0"/><path id="f08-l2" d="M1085 600 Q1260 470 1440 560" stroke="#FF9A3D" stroke-width="4" stroke-dasharray="12 12" fill="none" opacity="0"/></svg>
      <div class="bubble me" id="f08-hop" style="position:absolute;left:400px;top:520px;font-size:18px;opacity:0">On my way</div>""",
"""  tl.fromTo('#f08-h1', {y:30, opacity:0}, {y:0, opacity:1, duration:0.45, ease:'power3.out'}, 0.05);
  tl.fromTo(['#f08-p1','#f08-p2','#f08-p3'], {y:60, opacity:0}, {y:0, opacity:1, duration:0.6, stagger:0.15, ease:'power3.out'}, 0.2);
  tl.to('#f08-x', {opacity:1, duration:0.15}, 0.9);
  tl.to('#f08-wifi', {opacity:0.4, duration:0.3}, 1.0);
  tl.fromTo(q('.f08-rb'), {opacity:0, y:-20}, {opacity:1, y:0, duration:0.35, stagger:0.12}, 1.3);
  tl.fromTo('#f08-h2', {y:30, opacity:0}, {y:0, opacity:1, duration:0.45, ease:'power3.out'}, 1.7);
  tl.to(['#f08-l1','#f08-l2'], {opacity:1, duration:0.4, stagger:0.25}, 3.2);
  tl.fromTo('#f08-hop', {opacity:0, x:0, y:0}, {opacity:1, duration:0.2}, 3.6);
  tl.to('#f08-hop', {x:560, y:70, duration:0.9, ease:'power2.inOut'}, 3.7);
  tl.to('#f08-m2', {opacity:1, duration:0.2}, 4.5);
  tl.to('#f08-hop', {x:1150, y:0, duration:0.9, ease:'power2.inOut'}, 4.7);
  tl.to('#f08-hop', {opacity:0, duration:0.2}, 5.55);
  tl.to('#f08-m3', {opacity:1, duration:0.25}, 5.5);
  tl.fromTo('#f08-p3', {boxShadow:'0 40px 90px rgba(0,0,0,.6)'}, {boxShadow:'0 0 60px rgba(255,154,61,.55)', duration:0.5}, 5.6);
  tl.fromTo('#f08-cam', {x:60}, {x:-60, duration:D, ease:'power1.inOut'}, 0);
""")

# 09 bridge
F[9] = ("""      <div class="kicker" style="left:110px;top:110px">06 · bridge mode</div>
      <div class="h2" style="position:absolute;left:110px;top:150px;width:1500px"><span id="f09-h1">the first phone back in range</span><br><span class="ember" id="f09-h2">carries everyone home.</span></div>
      <div id="f09-arc" style="position:absolute;left:420px;top:330px;width:420px;height:420px;border-radius:50%;border:3px solid rgba(255,154,61,.35)"></div>
      """ + mini_phone('f09-p', 505, 340, '<div class="bubble me" style="font-size:14px">On my way <span id="f09-q" class="cs">· queued</span><span id="f09-ok" class="amber" style="opacity:0;font-weight:700"> ✓ sent</span></div><div class="bubble me" style="font-size:14px">SOS: north door</div><div class="bubble me" style="font-size:14px">Meera: radio dead</div>') + """
      <div id="f09-srv" style="position:absolute;left:1360px;top:430px;width:360px;height:200px;border-radius:26px;border:2px solid rgba(255,154,61,.6);display:flex;align-items:center;justify-content:center" class="mono"><span style="font-size:22px;letter-spacing:.14em;color:#FF9A3D">BUNNY HOP SERVER</span></div>
      <svg style="position:absolute;inset:0" width="1920" height="1080"><path id="f09-line" d="M760 560 L1360 530" stroke="#E85D18" stroke-width="5" fill="none" stroke-dasharray="620" stroke-dashoffset="620"/></svg>
      """ + ''.join(f'<div class="f09-pk" style="position:absolute;left:760px;top:{545 - i * 8}px;width:26px;height:26px;border-radius:8px;background:#FF9A3D;opacity:0"></div>' for i in range(3)),
"""  tl.fromTo('#f09-h1', {y:30, opacity:0}, {y:0, opacity:1, duration:0.45, ease:'power3.out'}, 0.05);
  tl.fromTo('#f09-p', {x:-200, opacity:0}, {x:0, opacity:1, duration:0.9, ease:'power2.out'}, 0.1);
  tl.fromTo('#f09-arc', {scale:0.6, opacity:0}, {scale:1, opacity:1, duration:0.9, ease:'power3.out'}, 0.6);
  tl.to('#f09-p', {boxShadow:'0 0 70px rgba(255,154,61,.6)', duration:0.5}, 1.2);
  tl.fromTo('#f09-srv', {opacity:0, scale:0.9}, {opacity:1, scale:1, duration:0.5, ease:'power3.out'}, 1.3);
  tl.to('#f09-line', {strokeDashoffset:0, duration:0.7, ease:'power2.inOut'}, 1.45);
  tl.fromTo('#f09-h2', {y:30, opacity:0}, {y:0, opacity:1, duration:0.45, ease:'power3.out'}, 1.6);
  tl.fromTo(q('.f09-pk'), {x:0, opacity:1}, {x:600, opacity:1, duration:0.8, stagger:0.25, ease:'power2.inOut'}, 1.9);
  tl.to(q('.f09-pk'), {opacity:0, duration:0.15, stagger:0.25}, 2.65);
  tl.to('#f09-q', {opacity:0, duration:0.2}, 3.0);
  tl.to('#f09-ok', {opacity:1, duration:0.3}, 3.05);
""")

# 10 SOS (orange register)
F[10] = ("""      <div style="position:absolute;left:0;right:0;top:90px;display:flex;flex-direction:column;align-items:center">
        <div style="position:relative;width:260px;height:260px">
          """ + ''.join(f'<div class="f10-ring" style="position:absolute;inset:0;border-radius:50%;border:5px solid #1B110B;opacity:0"></div>' for _ in range(3)) + """
          <div id="f10-btn" style="position:absolute;inset:0;border-radius:50%;background:#1B110B;color:#FF5D4F;display:flex;align-items:center;justify-content:center;font-weight:900;font-size:76px;letter-spacing:.08em">SOS</div>
          <span class="tap" id="f10-tap" style="left:98px;top:98px;opacity:0;border-color:#FFF6EA"></span>
        </div>
        <div class="display" style="color:#1B110B;margin-top:44px;font-size:150px;text-align:center"><span id="f10-a">one tap.</span><br><span id="f10-b">everyone knows.</span></div>
      </div>""",
"""  tl.fromTo('#f10-btn', {scale:0.4, opacity:0}, {scale:1, opacity:1, duration:0.5, ease:'back.out(1.8)'}, 0.0);
  tl.fromTo('#f10-tap', {scale:0.3, opacity:0}, {scale:1.1, opacity:1, duration:0.2}, 1.0);
  tl.to('#f10-tap', {scale:1.6, opacity:0, duration:0.35}, 1.2);
  tl.fromTo('#f10-btn', {scale:1}, {scale:0.92, duration:0.1, yoyo:true, repeat:1, immediateRender:false}, 1.05);
  tl.fromTo(q('.f10-ring'), {scale:1, opacity:0.9}, {scale:2.4, opacity:0, duration:1.2, stagger:0.3, ease:'power2.out'}, 1.15);
  tl.fromTo('#f10-a', {y:50, opacity:0}, {y:0, opacity:1, duration:0.45, ease:'power3.out'}, 2.1);
  tl.fromTo('#f10-b', {y:50, opacity:0}, {y:0, opacity:1, duration:0.45, ease:'power3.out'}, 2.55);
""")

# 11 control: phone slides left with soft spring, dashboard glides in
F[11] = ("""      """ + mini_phone('f11-ph', 150, 260, '<div class="ptitle" style="font-size:20px">Gate B</div><div class="psub amber">Encrypted</div>') + """
      <div class="dash" id="f11-dash" style="left:150px;right:150px;top:110px;height:740px">
        <div class="dbar"><img src="assets/logo.png" alt="" style="width:46px;height:46px;border-radius:50%"><b>Bunny Hop Control</b><span class="pill amber" style="color:#FF9A3D">● Live</span><span class="pill">No emergency</span><span style="flex:1"></span><span class="pill">26 of 28 online · 1 talking</span></div>
        <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:26px;padding:30px">
          <div class="card f11-cd" id="f11-gb" style="margin:0;padding:24px"><span><div class="cs" style="font-size:17px">HQ</div><div class="ct" style="font-size:32px">Gate B</div><div class="amber" id="f11-talk" style="font-size:21px;font-weight:600;opacity:0">▮▮▮ Ravi is talking</div></span></div>
          <div class="card f11-cd" style="margin:0;padding:24px"><span><div class="cs" style="font-size:17px">HQ</div><div class="ct" style="font-size:32px">Medical</div><div class="cs" style="font-size:21px">● 4 online</div></span></div>
          <div class="card f11-cd" style="margin:0;padding:24px"><span><div class="cs" style="font-size:17px">HQ</div><div class="ct" style="font-size:32px">Stage Crew</div><div class="cs" style="font-size:21px">● 6 online</div></span></div>
        </div>
        <div style="padding:0 30px"><div class="kicker" style="position:static;font-size:18px;margin-bottom:6px">activity</div>
          <div class="row" id="f11-r1"><span class="av"></span><span><b>Meera</b> <span class="muted">in Gate B</span> <span class="badge">Relayed via Joel</span><br>""" + chars("radio dead at north door, using mesh", "f11-t", "f11-t") + """</span></div>
          <div class="row" id="f11-r2"><span class="av"></span><span><b>Asha</b> <span class="muted">in Medical</span><br><span class="muted">🔒 Encrypted message</span></span></div>
        </div>
      </div>""",
"""  tl.fromTo('#f11-ph', {x:0, opacity:1}, {x:-520, opacity:0.0, duration:1.3, ease:'power2.inOut'}, 0);
  tl.fromTo('#f11-dash', {x:1700, rotationY:-8}, {x:0, rotationY:0, duration:1.4, ease:'back.out(0.9)', transformPerspective:2000}, 0.05);
  tl.fromTo(q('.f11-cd'), {y:40, opacity:0}, {y:0, opacity:1, duration:0.45, stagger:0.15, ease:'power3.out'}, 1.4);
  tl.to('#f11-gb', {borderColor:'rgba(255,154,61,.9)', boxShadow:'0 0 50px rgba(232,93,24,.45)', duration:0.4}, 2.8);
  tl.to('#f11-talk', {opacity:1, duration:0.3}, 2.8);
  tl.fromTo(['#f11-r1','#f11-r2'], {opacity:0, y:20}, {opacity:1, y:0, duration:0.35, stagger:0.4}, 2.9);
""" + type_in('.f11-t', 3.0, 0.03))

# 12 nodes matrix with typed counter
pattern = ['talk', '', '', '', '', '', '', 'near', '', '', '', '', '', 'off', '', 'near', '', '', '', '', '', '', 'off', '', '', '', '', '']
nodes = ''.join(f'<div class="node f12-n f12-{c or "on"}"></div>' for c in pattern)
F[12] = ("""      <div class="dash" id="f12-dash" style="left:150px;right:150px;top:110px;height:740px">
        <div class="dbar"><b>Nodes</b><span class="pill">every signed-in device, live</span><span style="flex:1"></span><span class="mono amber" style="font-size:28px;line-height:1.5;display:inline-block;padding-top:4px">""" + chars("26 of 28 online · 1 talking", "f12-c", "f12-c") + """</span></div>
        <div id="f12-grid" style="display:grid;grid-template-columns:repeat(14,1fr);gap:22px;padding:60px 50px 40px">""" + nodes.replace('class="node', 'style="aspect-ratio:1" class="node') + """</div>
        <div id="f12-leg" style="display:flex;gap:50px;padding:0 50px;font-size:24px;color:#C4AA94;opacity:0"><span><span class="ember">■</span> talking</span><span><span class="amber">■</span> online</span><span style="color:#FFD27A">■ nearby mode</span><span>■ offline</span></div>
      </div>""",
"""  tl.fromTo('#f12-dash', {opacity:0, y:30}, {opacity:1, y:0, duration:0.5, ease:'power3.out'}, 0);
""" + type_in('.f12-c', 0.3, 0.07) + """  tl.fromTo(q('.f12-n'), {scale:0, opacity:0}, {scale:1, opacity:1, duration:0.3, stagger:0.07, ease:'back.out(1.7)'}, 0.3);
  tl.to(q('.f12-talk'), {background:'#E85D18', boxShadow:'0 0 34px rgba(232,93,24,.95)', duration:0.4}, 2.45);
  tl.to(q('.f12-near'), {background:'#FFD27A', duration:0.4}, 3.3);
  tl.to(q('.f12-off'), {background:'rgba(125,101,83,.35)', duration:0.4}, 3.5);
  tl.to('#f12-leg', {opacity:1, duration:0.4}, 3.6);
  tl.fromTo('#f12-cam', {scale:1}, {scale:1.05, duration:D, ease:'power1.inOut', transformOrigin:'50% 45%'}, 0);
""")

# 13 audit
bars = [30, 55, 100, 70, 40, 62]
F[13] = ("""      <div style="position:absolute;left:110px;top:200px;display:flex;align-items:flex-end;gap:14px;height:360px">""" + ''.join(f'<div class="f13-bar" style="width:46px;height:{b}%;background:#d9701f;border-radius:8px 8px 0 0;transform-origin:50% 100%"></div>' for b in bars) + """</div>
      <div class="kicker" style="left:110px;top:590px">messages by hour</div>
      <div class="dash" id="f13-dash" style="left:620px;right:110px;top:110px;height:740px">
        <div class="dbar"><b>Gate B</b><span class="pill" style="color:#FFF6EA;border-color:#FF9A3D">History</span><span class="pill">Summary</span><span class="pill">Media</span></div>
        <div style="padding:16px 34px">
          <div class="row f13-r"><span class="av"></span><span><b>Ravi</b> <span class="muted">10:42</span><br>""" + chars("queue is moving, gate b clear", "f13-t1", "f13-t1") + """</span></div>
          <div class="row f13-r"><span class="av"></span><span><b>Meera</b> <span class="badge">Relayed via Meera</span><br>""" + chars("radio dead at north door, using mesh", "f13-t2", "f13-t2") + """</span></div>
          <div class="row f13-r"><span class="av"></span><span><b>Asha</b> <span class="muted">10:47</span><br><span style="display:inline-block;width:220px;height:120px;border-radius:12px;background:linear-gradient(135deg,#8a5a34,#3a2418);filter:blur(10px);vertical-align:middle"></span> <span class="badge" id="f13-flag" style="color:#FF5D4F;border-color:#FF5D4F;opacity:0">Sensitive content</span></span></div>
        </div>
      </div>""",
"""  tl.fromTo('#f13-dash', {x:420, opacity:0}, {x:0, opacity:1, duration:0.8, ease:'power2.inOut'}, 0);
  const bars = q('.f13-bar');
  tl.fromTo(bars, {scaleY:0}, {scaleY:1, duration:0.6, stagger:0.55, ease:'power3.out'}, 0.4);
  tl.fromTo(q('.f13-r'), {opacity:0, y:20}, {opacity:1, y:0, duration:0.35, stagger:1.1}, 1.2);
""" + type_in('.f13-t1', 1.4, 0.025) + type_in('.f13-t2', 2.5, 0.025) + """  tl.fromTo('#f13-flag', {scale:0.6, opacity:0}, {scale:1, opacity:1, duration:0.4, ease:'back.out(1.8)'}, 4.0);
""")

# 14 broadcast
F[14] = ("""      <div class="glowdot" id="f14-glow" style="left:460px;top:-80px;width:1000px;height:700px;background:radial-gradient(circle,rgba(255,93,79,.45),rgba(255,93,79,0) 70%);opacity:0"></div>
      <div class="dash" id="f14-dash" style="left:330px;right:330px;top:110px;height:740px">
        <div class="dbar"><b>Broadcast</b><span style="flex:1"></span><span class="pill" id="f14-sw">Emergency alert ○</span></div>
        <div style="padding:34px">
          <div class="field" style="font-size:34px;margin:0;padding:22px 26px"><b>""" + chars("Evacuate Hall C via Gate B", "f14-msg", "f14-msg") + """</b><span class="amber">|</span></div>
          <div class="btn" id="f14-send" style="font-size:28px;padding:20px;margin-top:24px">Send broadcast</div>
          <div style="display:flex;justify-content:space-between;margin-top:42px;font-size:30px"><b>Acknowledged</b><span class="mono amber" id="f14-n">0 of 14</span></div>
          <div style="height:22px;border-radius:20px;background:#342216;margin-top:16px;overflow:hidden"><div id="f14-bar" style="width:0%;height:100%;background:linear-gradient(90deg,#E85D18,#FF9A3D)"></div></div>
          <div style="display:flex;gap:14px;flex-wrap:wrap;margin-top:26px">""" + ''.join(f'<span class="badge f14-ack" style="font-size:22px;padding:4px 16px;opacity:0">✓ {n}</span>' for n in ['Asha', 'Ravi', 'Meera', 'Joel', 'Priya', 'Arun', 'Sam', 'Lena', 'Omar', 'Kiran', 'Tess', 'Vik']) + """</div>
        </div>
      </div>""",
"""  tl.fromTo('#f14-dash', {opacity:0, y:30}, {opacity:1, y:0, duration:0.5, ease:'power3.out'}, 0);
""" + type_in('.f14-msg', 0.25, 0.045) + """  tl.to('#f14-sw', {background:'#FF5D4F', color:'#ffffff', borderColor:'#FF5D4F', duration:0.25}, 1.6);
  tl.to('#f14-send', {background:'#FF5D4F', color:'#ffffff', duration:0.25}, 1.65);
  tl.to('#f14-glow', {opacity:1, duration:0.6}, 1.7);
  tl.fromTo('#f14-send', {scale:1}, {scale:0.95, duration:0.1, yoyo:true, repeat:1, immediateRender:false}, 2.1);
  const n = {v:0};
  tl.to(n, {v:12, duration:2.6, ease:'power1.inOut', onUpdate:()=>{ document.querySelector('[data-composition-id="14-broadcast"] #f14-n').textContent = Math.round(n.v) + ' of 14'; }}, 2.6);
  tl.to('#f14-bar', {width:'86%', duration:2.6, ease:'power1.inOut'}, 2.6);
  tl.fromTo(q('.f14-ack'), {opacity:0, scale:0.7}, {opacity:1, scale:1, duration:0.25, stagger:0.21, ease:'back.out(1.8)'}, 2.65);
""")

# 15 end card (final frame: may fade out)
F[15] = ("""      <div class="glowdot" id="f15-glow" style="left:690px;top:60px;width:540px;height:540px"></div>
      <div style="position:absolute;left:0;right:0;top:110px;display:flex;flex-direction:column;align-items:center">
        <div style="position:relative;width:260px;height:260px">
          <svg width="260" height="260" viewBox="0 0 260 260" style="position:absolute;inset:0"><circle id="f15-ring" cx="130" cy="130" r="125" fill="none" stroke="#E85D18" stroke-width="3" stroke-dasharray="786" stroke-dashoffset="786" transform="rotate(-90 130 130)"/></svg>
          <img id="f15-logo" src="assets/logo.png" alt="" style="position:absolute;left:16px;top:16px;width:228px;height:228px;border-radius:50%">
        </div>
        <div class="display" id="f15-word" style="margin-top:34px;font-size:150px">bunny hop</div>
        <div class="h2" id="f15-tag" style="margin-top:10px;font-size:58px">your team, <span class="ember">one press away.</span></div>
        <div class="kicker" id="f15-off" style="position:relative;margin-top:30px;color:#C4AA94;font-size:22px">runs on your own network · no internet needed</div>
      </div>""",
"""  tl.to('#f15-ring', {strokeDashoffset:0, duration:1.0, ease:'power2.inOut'}, 0);
  tl.fromTo('#f15-glow', {opacity:0, scale:0.5}, {opacity:1, scale:1, duration:1.0, ease:'power3.out'}, 0.1);
  tl.fromTo('#f15-logo', {scale:0.6, opacity:0}, {scale:1, opacity:1, duration:0.7, ease:'back.out(1.6)'}, 0.2);
  tl.fromTo('#f15-word', {y:60, opacity:0}, {y:0, opacity:1, duration:0.6, ease:'power3.out'}, 1.4);
  tl.fromTo('#f15-tag', {y:40, opacity:0}, {y:0, opacity:1, duration:0.6, ease:'power3.out'}, 2.0);
  tl.fromTo('#f15-off', {opacity:0}, {opacity:1, duration:0.6}, 3.0);
  tl.to('#f15-cam', {opacity:0, duration:0.6, ease:'power2.in'}, D - 0.6);
""")

os.makedirs(os.path.join(ROOT, 'compositions', 'frames'), exist_ok=True)
for num, (body, js) in F.items():
    dur, fid = DUR[num]
    html = frame(num, body, js, orange=(num == 10))
    with open(os.path.join(ROOT, 'compositions', 'frames', fid + '.html'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(html)
    print(f'{fid}: {dur}s')
