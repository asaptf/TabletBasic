#!/usr/bin/env python3
"""Render editable SVG App Store creatives to opaque sRGB PNGs.
Requires Pillow and CairoSVG; uses the existing TabletBasic terminal palette.
"""
from pathlib import Path
import math
import cairosvg
from PIL import Image, ImageCms

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'fastlane/creative/en-US'
MINT = '#65ffd5'
WHITE = '#f4f8ff'


def text(x, y, value, size, color=WHITE, weight=400, anchor='middle', family='Menlo'):
    from html import escape
    return f'<text x="{x}" y="{y}" fill="{color}" font-family="{family}" font-size="{size}" font-weight="{weight}" text-anchor="{anchor}">{escape(value)}</text>'


def base(w, h):
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">', '''<defs>
      <linearGradient id="bg" x2="1" y2="1"><stop stop-color="#112549"/><stop offset=".55" stop-color="#081326"/><stop offset="1" stop-color="#031c21"/></linearGradient>
      <radialGradient id="halo"><stop stop-color="#2ad9b9" stop-opacity=".18"/><stop offset="1" stop-color="#2ad9b9" stop-opacity="0"/></radialGradient>
      <linearGradient id="edge"><stop stop-color="#65ffd5" stop-opacity=".08"/><stop offset=".5" stop-color="#65ffd5" stop-opacity=".7"/><stop offset="1" stop-color="#65ffd5" stop-opacity=".08"/></linearGradient>
      <linearGradient id="card" x2="0" y2="1"><stop stop-color="#111f36"/><stop offset="1" stop-color="#08111f"/></linearGradient>
    </defs>''', f'<rect width="{w}" height="{h}" fill="url(#bg)"/>', f'<ellipse cx="{w/2}" cy="{h/2}" rx="{w*.46}" ry="{h*.7}" fill="url(#halo)"/>']
    # The large perimeter plot echoes BASIC graphics without competing with the copy.
    for j in range(22):
        pts=[]
        for i in range(121):
            a=i/120*math.tau
            r=1+.12*math.sin(3*a+j*.035)
            x=w/2+math.cos(a)*w*(.34+j*.006)*r
            y=h/2+math.sin(a)*h*(.28+j*.010)*r
            pts.append(f'{x:.1f},{y:.1f}')
        s.append(f'<polyline points="{" ".join(pts)}" fill="none" stroke="{MINT}" stroke-width="1.4" opacity="{.035+j*.0015}"/>')
    for x,y in [(w*.13,h*.25),(w*.84,h*.20),(w*.19,h*.78),(w*.9,h*.72)]:
        s.append(f'<path d="M{x-18},{y}h36 M{x},{y-18}v36" stroke="#7b9fb5" stroke-width="3" opacity=".35"/>')
    return s


def frame(s, x,y,w,h):
    s.append(f'<rect x="{x+12}" y="{y+28}" width="{w}" height="{h}" rx="38" fill="#000713" opacity=".45"/>')
    s.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="38" fill="url(#card)" stroke="url(#edge)" stroke-width="3"/>')
    s.append(f'<path d="M{x+35},{y+110}H{x+w-35}" stroke="#304356" stroke-width="2"/>')
    for i,col in enumerate(['#6b8799', '#ead68b', MINT]):
        s.append(f'<rect x="{x+48+i*35}" y="{y+45}" width="16" height="16" rx="3" fill="{col}" opacity=".85"/>')


def save(name,s,w,h):
    s.append('</svg>')
    svg='\n'.join(s)
    (OUT/f'{name}.svg').write_text(svg)
    path=OUT/f'{name}.png'
    cairosvg.svg2png(bytestring=svg.encode(),write_to=str(path))
    im=Image.open(path).convert('RGB')
    profile=ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
    im.save(path,icc_profile=profile,optimize=True)
    preview=im.copy();preview.thumbnail((1440,960));preview.save(OUT/f'{name}-preview.png')
    print(name,im.size,im.mode,path.stat().st_size)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    w,h=3840,1646
    s=base(w,h)
    frame(s,900,360,2040,925)
    s.append(text(1920,433,'TABLETBASIC',39,'#a7bbc9',500))
    s.append(text(1920,639,'Your next idea starts with',49,'#99acbd'))
    s.append(text(1920,875,'HELLO, WORLD.',164,MINT,700))
    s.append(text(1920,1030,'Learn BASIC. Make it run.',59,WHITE,400))
    s.append('<rect x="1800" y="1130" width="240" height="7" rx="3" fill="url(#edge)"/>')
    # Decoration outside the centered safe area remains dispensable when cropped.
    s.append(text(730,1120,'10',41,'#557288',400,'end'))
    s.append(text(3170,560,'RUN',41,'#557288',400,'start'))
    save('tabletbasic-header-v1',s,w,h)

    w,h=3840,2560
    s=base(w,h)
    s.append(text(1920,740,'TABLETBASIC',55,'#b4c5d3',500))
    s.append(text(1920,1010,'Learn BASIC.',170,WHITE,700))
    s.append(text(1920,1230,'Make it run.',170,MINT,700))
    frame(s,1070,1310,1700,480)
    s.append(text(1920,1382,'HELLO.BAS',38,'#a0b6c7'))
    s.append(text(1190,1510,'10',59,'#5f8096',400,'start'))
    s.append(text(1340,1510,'PRINT',68,'#70dfff',500,'start'))
    s.append(text(1600,1510,'"Hello, World!"',68,'#f6e59b',400,'start'))
    s.append('<path d="M1190,1580H2650" stroke="#293d50" stroke-width="2"/>')
    s.append(text(1190,1710,'Hello, World!',68,MINT,400,'start'))
    s.append('<rect x="1750" y="1652" width="33" height="64" fill="#65ffd5"/>')
    s.append('<path d="M2540,1438l82,52-82,52Z" fill="#65ffd5"/>')
    save('tabletbasic-search-results-v1',s,w,h)


if __name__=='__main__':main()
