"""Deterministic dense-forest layout generator (PROPOSAL ONLY). Seeded; no Studio writes."""
import math, random, numpy as np
import os
_b36 = '0123456789abcdefghijklmnopqrstuvwxyz'
def _load_grid(path=os.path.join(os.path.dirname(os.path.abspath(__file__)), 'terrain_grid_8stud.txt')):
    # Studio raycast sample (read-only), 8-stud grid: rows Z=-236..236, cols X=2724..3276; cell = 2 base36 chars (Y+20) + normal.Y*10 digit
    L = [l for l in open(path).read().split('\n') if l and not l.startswith('#')]
    H = np.zeros((len(L), 70)); N = np.zeros_like(H)
    for i, l in enumerate(L):
        for j in range(70):
            c = l[3*j:3*j+3]; H[i, j] = _b36.index(c[0]) * 36 + _b36.index(c[1]) - 20; N[i, j] = int(c[2])
    return H, N
H, N = _load_grid()
X0, Z0, CELL = 2724, -236, 8

def terrain(x, z):
    j = int(round((x - X0) / CELL)); i = int(round((z - Z0) / CELL))
    if not (0 <= i < H.shape[0] and 0 <= j < H.shape[1]): return None
    sl = H[max(0, i-1):i+2, max(0, j-1):j+2]
    return H[i, j], N[i, j], sl.max() - sl.min()

PATHS = [((2810,0),(2944,0)), ((2920,-160),(3140,-160)), ((2920,160),(3140,160)), ((2920,-160),(2920,160)),
         ((3140,-160),(3140,160)), ((2850,-25),(2850,-10)), ((2850,-10),(2920,-10)), ((3140,-160),(3150,-150)), ((3140,160),(3220,150))]
def seg_dist(px, pz, a, b):
    ax, az = a; bx, bz = b; dx, dz = bx-ax, bz-az
    t = max(0, min(1, ((px-ax)*dx + (pz-az)*dz) / (dx*dx + dz*dz)))
    return math.hypot(px - ax - t*dx, pz - az - t*dz)

KEEP_OUT = [  # (kind, params, clearance) — preserved features
  ('rect', (2790, 0, 22, 22), 8),      # arrival plaza floor 44x44 (+ return pad at 2775,16)
  ('rect', (2818, 0, 6, 6), 6),        # ramp
  ('rect', (2850, -40, 20, 15), 6),    # station clearing
  ('circ', (3150, -150, 56), 8),       # future boss arena
  ('circ', (3220, 150, 14), 6),        # portal clearing
  ('rect', (3150, -120, 70, 60), 4),   # CW Golden Slime spawn zone X3080-3220 Z-180..-60
  ('circ', (2940, 128, 8), 0),         # Studio raycast: slope > 30 deg (canyon rim)
  ('circ', (2995, -193, 9), 0),        # Studio raycast: slope > 30 deg
  ('circ', (2896, 91, 3), 0),          # Studio raycast: slope > 30 deg
]
def blocked(x, z, path_clear):
    for kind, p, c in KEEP_OUT:
        if kind == 'rect':
            if abs(x - p[0]) <= p[2] + c and abs(z - p[1]) <= p[3] + c: return True
        elif math.hypot(x - p[0], z - p[1]) <= p[2] + c: return True
    if any(seg_dist(x, z, a, b) < path_clear for a, b in PATHS): return True
    if not (2732 <= x <= 3268 and -228 <= z <= 228): return True
    return False

def ground_ok(x, z, band):
    t = terrain(x, z)
    if t is None: return False
    h, n, relief = t
    return n >= 8 and relief <= 3.5 and band[0] <= h <= band[1]

def lattice(zone, s, rng, jitter=0.15):
    cx, cz, a, b, ang = zone['cx'], zone['cz'], zone['a'], zone['b'], math.radians(zone.get('ang', 0))
    ox, oz = rng.uniform(0, s), rng.uniform(0, s); rot = rng.uniform(0, math.pi / 3)
    R = max(a, b) * 1.6; pts = []
    row_h = s * math.sqrt(3) / 2
    for r in range(-int(R / row_h) - 2, int(R / row_h) + 3):
        for c in range(-int(R / s) - 2, int(R / s) + 3):
            u = c * s + (r % 2) * s / 2 + ox; v = r * row_h + oz
            u += rng.uniform(-jitter, jitter) * s; v += rng.uniform(-jitter, jitter) * s
            x = cx + u * math.cos(rot) - v * math.sin(rot); z = cz + u * math.sin(rot) + v * math.cos(rot)
            # elliptical radius in zone frame
            ex = (x - cx) * math.cos(ang) + (z - cz) * math.sin(ang); ez = -(x - cx) * math.sin(ang) + (z - cz) * math.cos(ang)
            pts.append((x, z, math.hypot(ex / a, ez / b)))
    return pts

def place_zone(zone, n, s, rng, path_clear=6.5, lanes=None, landmarks=()):
    pts = lattice(zone, s, rng)
    out = []
    for x, z, er in sorted(pts, key=lambda p: p[2]):
        if er > 1.6: break
        if blocked(x, z, path_clear) or not ground_ok(x, z, zone['band']): continue
        if lanes and any(seg_dist(x, z, a, b) < lanes[1] for a, b in lanes[0]): continue
        if any(math.hypot(x - lx, z - lz) < lr and math.hypot(x - lx, z - lz) > 0.01 for lx, lz, lr in landmarks): continue
        out.append((x, z, er))
        if len(out) == n: break
    return out

ZONES_A = [
  dict(id='Z1', name='Arrival Thicket', cx=2888, cz=14,   a=44, b=34, band=(2.5, 6.5), n=155),
  dict(id='Z2', name='Gorge Grove',     cx=3000, cz=-15,  a=34, b=58, band=(0.5, 3.5), n=155),
  dict(id='Z3', name='North Shardwood', cx=2895, cz=130,  a=46, b=32, band=(2.5, 6.5), n=150),
  dict(id='Z4', name='South Hollow',    cx=3030, cz=-190, a=44, b=30, band=(2.5, 6.5), n=140),
]
POCKETS = [  # breadcrumb mini-clusters along connectors (5 trees each)
  dict(id='P1', name='Ridge pocket N', cx=2934, cz=70,  a=7, b=7, band=(2.5, 7.5), n=5),
  dict(id='P2', name='Ridge pocket S', cx=2905, cz=-75, a=7, b=7, band=(2.5, 7.5), n=5),
  dict(id='P3', name='Gorge pocket 1', cx=2992, cz=-98, a=7, b=7, band=(0.5, 3.5), n=5),
  dict(id='P4', name='Gorge pocket 2', cx=2985, cz=-128,a=7, b=7, band=(0.5, 4.5), n=5),
]
