import numpy as np, matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Circle, Ellipse
import gen, layouts, exp, sim
H = gen.H
COL={'Common':'#9a9aa2','Uncommon':'#3fae4a','Rare':'#3b7ddd','Epic':'#9b3fe0','Legendary':'#e0a020','Mythic':'#e0304f','Secret':'#111111'}
def base(ax,title):
    ax.imshow(H,origin='lower',extent=(2720,3280,-240,240),cmap='Greys',vmin=-5,vmax=50,alpha=0.55)
    for a,b in gen.PATHS: ax.plot([a[0],b[0]],[a[1],b[1]],color='#c8a46e',lw=3.2,solid_capstyle='round',zorder=2)
    ax.add_patch(Rectangle((2768,-22),44,44,fc='#ffe9a8',ec='#b08000',lw=1.2,zorder=3)); ax.text(2790,-31,'Arrival plaza',ha='center',fontsize=7)
    ax.plot(2775,16,'s',color='#2a9d4b',ms=6,zorder=4); ax.text(2775,24,'Return pad',ha='center',fontsize=6)
    ax.add_patch(Rectangle((2830,-55),40,30,fc='none',ec='#b08000',ls='--',zorder=3)); ax.text(2850,-62,'Station clearing',ha='center',fontsize=6)
    ax.add_patch(Circle((3150,-150),56,fc='#ffd6d6',ec='#c02020',ls='--',alpha=.6,zorder=3)); ax.text(3150,-150,'Future boss\nclearing (r56)',ha='center',va='center',fontsize=7)
    ax.add_patch(Rectangle((3080,-180),140,120,fc='#fff3a0',ec='#c09000',alpha=.35,zorder=3)); ax.text(3150,-70,'Golden Slime zone',ha='center',fontsize=7)
    ax.add_patch(Circle((3220,150),14,fc='#d8c8ff',ec='#6040c0',zorder=3)); ax.text(3220,170,'Portal clearing',ha='center',fontsize=6)
    ax.add_patch(Rectangle((2944,-136),172,272,fc='none',ec='#7a5a30',ls=':',lw=1,zorder=3)); ax.text(3110,128,'Copied canyon core\n(cliffs shaded dark)',fontsize=6,ha='right',color='#7a5a30')
    ax.add_patch(Rectangle((2720,-240),560,480,fc='none',ec='k',lw=1.5))
    ax.set_xlim(2715,3285); ax.set_ylim(-245,245); ax.set_aspect('equal'); ax.set_title(title,fontsize=10)
    ax.set_xlabel('X (studs)'); ax.set_ylabel('Z (studs)'); ax.grid(alpha=.15)
def trees(ax,rows,s=4):
    for t,c in COL.items():
        pts=[(r[0],r[2]) for r in rows if r[3]==t]
        if pts: P=np.array(pts); ax.scatter(P[:,0],P[:,1],s=s if t not in('Mythic','Secret','Legendary') else 22,c=c,label=f"{t} ({len(pts)})",zorder=5,edgecolors='none' if t!='Secret' else 'w',linewidths=.5)
L=layouts.build('A')
fig,ax=plt.subplots(figsize=(11,9.6)); base(ax,'Crystal Wilds — PROPOSED Option A (4 dense zones + 4 trail pockets, 620 trees)')
trees(ax,layouts.rows(L))
for z in gen.ZONES_A:
    ax.add_patch(Ellipse((z['cx'],z['cz']),2*z['a'],2*z['b'],fc='none',ec='#1060a0',lw=1,ls='--',zorder=4))
    ax.text(z['cx'],z['cz']+z['b']+5,f"{z['id']} {z['name']}\n{z['n']} trees",ha='center',fontsize=8,color='#0a3d6b',weight='bold',zorder=6)
for p in gen.POCKETS: ax.text(p['cx']+9,p['cz'],p['id'],fontsize=7,color='#0a3d6b')
for k,(x,z) in layouts.LANDMARKS.items(): ax.plot(x,z,'*',ms=13,mfc='none',mec='#c00000',zorder=6)
R=np.array(exp.ROUTE); ax.plot(R[:,0],R[:,1],color='#d02090',lw=1,ls='-.',zorder=6,label='30-s sim walk route')
ax.legend(loc='upper right',fontsize=7,framealpha=.9); fig.tight_layout(); fig.savefig('blueprint_A.png',dpi=130)
fig,axs=plt.subplots(1,2,figsize=(17,7.8))
base(axs[0],'CURRENT build (v12): 620 trees, nearest-neighbour 12.0 studs'); trees(axs[0],exp.LAYOUTS['Current'],3)
base(axs[1],'Option B (concentrated, lattice 4.5): nearest-neighbour 3.9 studs'); trees(axs[1],exp.LAYOUTS['B'],3)
axs[0].legend(loc='upper right',fontsize=6); fig.subplots_adjust(left=.05,right=.98,wspace=.12); fig.savefig('current_vs_B.png',dpi=110)
fig,ax=plt.subplots(figsize=(7,8)); base(ax,'Zoom: Z2 Gorge Grove with blade envelopes (to scale)')
trees(ax,layouts.rows(L),14); cx,cz=2995,-10
for pr,c in zip(sim.PROFILES[1:],['#2a9d4b','#1f6fd0','#c03030']):
    e=sim.envelope(pr)
    ax.add_patch(Circle((cx,cz),e['centre_max'],fc='none',ec=c,lw=1.6)); ax.add_patch(Circle((cx,cz),e['centre_min'],fc='none',ec=c,lw=1,ls=':'))
    ax.text(cx+e['centre_max']*0.71,cz+e['centre_max']*0.71,pr['name'].split(' (')[0],color=c,fontsize=7)
ax.plot(cx,cz,'kx',ms=8); ax.set_xlim(2955,3045); ax.set_ylim(-80,45); fig.tight_layout(); fig.savefig('zoom_Z2_envelopes.png',dpi=120)
print('ok')
