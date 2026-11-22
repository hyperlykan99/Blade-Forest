"""Render the actual prepared glTF triangles for visual review outside Studio."""
import argparse
import importlib.util
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location("catalog", HERE / "build_professional_assets.py")
catalog = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(catalog)


def render(tris, colors, camera, target, size=(1260, 698), fov=49):
    w,h=size
    camera=np.array(camera,dtype=float)
    forward=np.array(target,dtype=float)-camera
    forward/=np.linalg.norm(forward)
    right=np.cross(forward,[0,1,0])
    right/=np.linalg.norm(right)
    up=np.cross(right,forward)
    p=(tris-camera)@np.array([right,up,forward]).T
    factor=h/(2*np.tan(np.radians(fov/2)))
    screen=p[:,:,:2]/np.maximum(.06,p[:,:,2:])*[factor,-factor]+[w/2,h/2]
    normal=np.cross(tris[:,1]-tris[:,0],tris[:,2]-tris[:,0])
    norm=np.maximum(np.linalg.norm(normal,axis=1),1e-9)
    light=np.maximum(0,normal@np.array([-.36,.77,.53])/norm)
    shade=.56+light*.50
    rgb=colors*shade[:,None]
    depth=np.full((h,w),np.inf)
    row=np.linspace(0,1,h)[:,None,None]
    bg=np.broadcast_to(np.rint(np.array([149,180,177])*(1-row)+np.array([229,215,183])*row),(h,w,3)).astype(np.uint8).copy()
    for i,(triangle,d) in enumerate(zip(screen,p[:,:,2])):
        if np.any(d<=.06):continue
        low=np.maximum([0,0],np.floor(triangle.min(axis=0)).astype(int))
        high=np.minimum([w,h],np.ceil(triangle.max(axis=0)).astype(int)+1)
        x0,y0=low;x1,y1=high
        if x0>=x1 or y0>=y1:continue
        xs,ys=np.meshgrid(np.arange(x0,x1)+.5,np.arange(y0,y1)+.5)
        a,b,c=triangle
        det=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(det)<1e-7:continue
        u=((b[1]-c[1])*(xs-c[0])+(c[0]-b[0])*(ys-c[1]))/det
        v=((c[1]-a[1])*(xs-c[0])+(a[0]-c[0])*(ys-c[1]))/det
        k=1-u-v
        z=1/np.maximum(.001,u/d[0]+v/d[1]+k/d[2])
        region=depth[y0:y1,x0:x1]
        valid=(u>=0)&(v>=0)&(k>=0)&(z<region)
        region[valid]=z[valid]
        bg[y0:y1,x0:x1][valid]=np.clip(rgb[i],0,255)
    return Image.fromarray(bg)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("asset_root",type=Path)
    parser.add_argument("output",type=Path)
    args=parser.parse_args()
    files={p.stem:p for p in args.asset_root.glob("kenney-*/Models/**/*.glb")}
    def load(stem):
        return catalog.gltf(files[stem])
    def element(name,x,y,z,s=1,angle=0):
        if name in {"RecordsHall","Cottage","Workshop"}:
            tris,colors=catalog.building(name,load)
        else:
            stem,h=catalog.FAMILY[name]
            tris,colors=load(stem)
            if name in {"GateArch","WinterArch"}:
                tris,colors=catalog.gateway(tris,colors)
            tris=catalog.normalized(tris,h)
        colors=catalog.grade(name,tris,colors)
        return catalog.axis_rotate(tris*s,angle)+[x,y,z], colors
    layout=(
        ("Cottage",-3,0,-3,1,math.pi+.3),("Workshop",5,0,-6,1,math.pi-.14),
        ("TallPine",-6,0,-5,1.12,.43),("TallPine",8,0,-9,1.08,.8),
        ("GoldenOak",-6,0,-.5,1,-.3),("Sapling",6,0,-1,1,.2),
        ("Sapling",8,0,-2,.9,.6),("Fern",-5.6,0,.4,1.7,0),
        ("Foxglove",-5.2,0,1,1.5,0),("Foxglove",4,0,1,1.4,0),
        ("Bridge",.6,.02,3.0,2,math.pi/2),
        ("River",.65,0,2.95,2.4,0),("River",3,0,2.95,2.4,0),("River",-1.7,0,2.95,2.4,0),
        ("Boulder",-2,0,2.5,1.4,0),("Boulder",3.4,0,3,1.7,.7),
        ("Trail",.4,0,1.1,1.7,0),("Trail",.4,0,-1,1.6,0),
        ("MarketStall",3.9,0,-1.5,1.1,.24),("Lantern",4.4,1.1,-.8,.75,0),
        ("Cart",-2,0,-.1,1.3,.6),("Fence",-5.5,0,2,1.5,.1),
        ("Fence",5.2,0,2.1,1.4,-.1),("GateArch",.35,0,-5,1.7,0),
    )
    assets=[element(*s) for s in layout]
    # An undetailed receiver is only used by this turntable render.
    base=np.array([[[-42,-.025,38],[42,-.025,38],[-42,-.025,-46]],
                   [[42,-.025,38],[42,-.025,-46],[-42,-.025,-46]]],dtype=float)
    assets.append((base,np.array([[108,131,105],[108,131,105]])))
    tris,colors=catalog.merge(assets)
    result=render(tris,colors,(-6.8,2.8,10),(.1,2.35,-3.9))
    draw=ImageDraw.Draw(result)
    title=ImageFont.truetype("/System/Library/Fonts/Supplemental/Georgia.ttf",26)
    face=ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf",16)
    draw.rectangle((0,629,1260,698),fill="#26322e")
    draw.text((28,637),"Blade Forest · Source mesh review",font=title,fill="#f5efdf")
    draw.text((30,673),"Kenney Fantasy Town Kit and Nature Kit  •  Staged composition render from authored mesh data",font=face,fill="#b9c4b3")
    result.save(args.output)


if __name__=="__main__":
    main()
