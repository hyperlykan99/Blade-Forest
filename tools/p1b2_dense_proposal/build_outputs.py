import os
import json, zlib, collections, numpy as np, layouts
from scipy.spatial import ConvexHull, cKDTree
yd=json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'ydict_A.json')))
L=layouts.build('A'); lines=[]; srcs=[]
for zid,x,z,r,lm in L:
    lines.append(f"{zid},{x:.1f},{yd[f'{x:.1f},{z:.1f}']:.2f},{z:.1f},{r['type']},{r['scale']:.2f},{int(r['rot'])},{r['mut']},{r['src']},{1 if lm else 0}"); srcs.append(r['src'])
assert sorted(srcs)==list(range(1,621))
body='\n'.join(lines); hdr='zone,x,y,z,type,scale,rotY,mutation,src_row,landmark'
open('dense_A.csv','w').write(hdr+'\n'+body+'\n')
print('A', len(lines), len(body), zlib.adler32(body.encode()))
