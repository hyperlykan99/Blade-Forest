"""Prepare CC0 static meshes for Studio without requiring Blender or changing the source packs."""
import argparse
import base64
import io
import json
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image

COMPONENTS = {5121: "u1", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
DIMENSIONS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}
PALETTE_SIZE = 64
CELL = 4


def gltf(path):
    data = path.read_bytes()
    if data[:4] == b"glTF":
        size, = struct.unpack_from("<I", data, 12)
        info = json.loads(data[20:20 + size])
        embedded = data[28 + size:]
    else:
        info, embedded = json.loads(data), b""

    def uri(value):
        if value.startswith("data:"):
            return base64.b64decode(value.split(",", 1)[1])
        source = (path.parent / value).resolve()
        if not source.is_relative_to(path.parent.resolve()):
            raise ValueError(f"External dependency escaped the source directory: {value}")
        return source.read_bytes()

    buffers = [uri(b["uri"]) if "uri" in b else embedded for b in info["buffers"]]

    def array(i):
        a = info["accessors"][i]
        view = info["bufferViews"][a["bufferView"]]
        comp = np.dtype(COMPONENTS[a["componentType"]])
        dim = DIMENSIONS[a["type"]]
        offset = a.get("byteOffset", 0) + view.get("byteOffset", 0)
        step = view.get("byteStride", comp.itemsize * dim)
        return np.ndarray((a["count"], dim), comp, buffers[view["buffer"]], offset, (step, comp.itemsize))

    def image(i):
        img = info["images"][i]
        if "uri" in img:
            raw = uri(img["uri"])
        else:
            view = info["bufferViews"][img["bufferView"]]
            begin = view.get("byteOffset", 0)
            raw = buffers[view["buffer"]][begin:begin + view["byteLength"]]
        return np.asarray(Image.open(io.BytesIO(raw)).convert("RGB"))

    def transform(n):
        if "matrix" in n:
            return np.array(n["matrix"]).reshape((4, 4), order="F")
        x, y, z, w = n.get("rotation", [0, 0, 0, 1])
        matrix = np.array([
            [1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w), 0],
            [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w), 0],
            [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y), 0],
            [0, 0, 0, 1],
        ])
        matrix[:3, :3] *= n.get("scale", [1, 1, 1])
        matrix[:3, 3] = n.get("translation", [0, 0, 0])
        return matrix

    def visit(index, parent):
        node = info["nodes"][index]
        frame = parent @ transform(node)
        if "mesh" in node:
            for primitive in info["meshes"][node["mesh"]]["primitives"]:
                if primitive.get("mode", 4) != 4:
                    raise ValueError(f"{path.name} uses a non-triangle primitive")
                attrs = primitive["attributes"]
                pos = array(attrs["POSITION"])
                idx = (array(primitive["indices"]).ravel() if "indices" in primitive else np.arange(len(pos))).reshape(-1, 3)
                if np.linalg.det(frame[:3, :3]) < 0:
                    idx = idx[:, [0, 2, 1]]
                vertices = pos[idx] @ frame[:3, :3].T + frame[:3, 3]
                material = info["materials"][primitive["material"]] if "material" in primitive else {}
                props = material.get("pbrMetallicRoughness", {})
                linear = np.array(props.get("baseColorFactor", [1, 1, 1, 1]))[:3]
                base = np.where(linear <= .0031308, 12.92*linear, 1.055*linear**(1/2.4)-.055)
                if "baseColorTexture" in props:
                    texture = info["textures"][props["baseColorTexture"]["index"]]
                    pix = image(texture["source"])
                    uv = array(attrs["TEXCOORD_0"])[idx].mean(axis=1)
                    coords = (uv * [pix.shape[1], pix.shape[0]]).astype(int)
                    cols = pix[coords[:, 1] % pix.shape[0], coords[:, 0] % pix.shape[1]] * base
                else:
                    cols = np.tile(np.rint(base*255), (len(idx), 1))
                yield vertices, cols
        for child in node.get("children", []):
            yield from visit(child, frame)

    triangles, colors = zip(*(piece for n in info["scenes"][info.get("scene", 0)]["nodes"] for piece in visit(n, np.eye(4))))
    return np.concatenate(triangles), np.concatenate(colors)


FAMILY = {
    "Sapling": ("tree_small", 2.8), "Blossom": ("tree_detailed", 3.8),
    "AutumnMaple": ("tree_default_fall", 4.4), "RubyMaple": ("tree_detailed_fall", 4.8),
    "GoldenOak": ("tree_oak_fall", 5.4), "Sakura": ("tree_fat", 5.9), "AncientCrown": ("tree_plateau", 6.4),
    "Spruce": ("tree_pineDefaultA", 4.3), "TallPine": ("tree_pineTallB_detailed", 5.8),
    "FrostSpruce": ("tree_pineRoundC", 5.0), "EmberPine": ("tree_pineTallC_detailed", 6.1),
    "GoldenPine": ("tree_pineGroundA", 6.6), "GiantMushroom": ("mushroom_tanGroup", 4.4),
    "MoonlitBonsai": ("tree_plateau_dark", 6.5),
    "SnowPine": ("tree_pineRoundB", 5.0), "GlacierPine": ("tree_pineTallD_detailed", 6.2),
    "Frostwood": ("tree_pineSmallD", 5.7), "AuroraPine": ("tree_pineRoundF", 6.6),
    "Starfrost": ("tree_pineRoundD", 7.0), "Frostleaf": ("tree_pineGroundB", 7.4),
    "FrostGiant": ("tree_pineTallA_detailed", 8.0),
    "Bridge": ("bridge_woodRound", None), "Trail": ("path_stone", None),
    "River": ("ground_riverStraight", None), "Waterfall": ("cliff_waterfall_rock", None),
    "Boulder": ("rock_largeC", None), "Cliff": ("cliff_blockSlope_rock", None),
    "Crystal": ("rock_tallF", None), "CrystalSpine": ("rock_tallA", None),
    "Fern": ("plant_flatTall", None), "Foxglove": ("flower_purpleA", None),
    "Fence": ("fence_planksDouble", None), "NurseLog": ("log_large", None),
    "Cart": ("cart-high", None), "Lantern": ("lantern", None),
    "MarketStall": ("stall-green", None), "GateArch": ("wall-doorway-round", None),
    "RuinedWall": ("wall-broken", None), "WinterArch": ("wall-wood-doorway-round", None),
    "Pavers": ("path_stoneCircle", None), "TimberSign": ("banner-green", None),
}
SNOW = {"SnowPine", "GlacierPine", "Frostwood", "AuroraPine", "Starfrost", "Frostleaf", "FrostGiant"}
ACCENTS = {
    "Sakura": (198, 117, 134), "AncientCrown": (126, 143, 179), "MoonlitBonsai": (82, 133, 118),
    "EmberPine": (180, 107, 72), "GoldenPine": (206, 170, 92),
    "Crystal": (88, 166, 172), "CrystalSpine": (124, 114, 174),
}


def normalized(triangles, height=None):
    lo, hi = triangles.min(axis=(0, 1)), triangles.max(axis=(0, 1))
    triangles = triangles - np.array([(lo[0]+hi[0])/2, lo[1], (lo[2]+hi[2])/2])
    if height:
        triangles *= height / (hi[1] - lo[1])
    return triangles


def grade(name, triangles, columns):
    cols = columns*.85 + columns.mean(axis=1, keepdims=True)*.15
    y = triangles[:, :, 1].mean(axis=1)
    foliage = y > (triangles[:, :, 1].max() * .28)
    green = cols[:, 1] > cols[:, 0] * .88
    if name in SNOW:
        mask = foliage & green
        color = np.array([145, 183, 194]) + (y / max(y.max(), .01))[:, None]*np.array([51, 50, 48])
        cols[mask] = cols[mask] * .25 + color[mask] * .75
    if name == "WinterArch":
        cols = cols*.48 + np.array([140,169,187])*.52
    if name in ACCENTS:
        mask = np.ones(len(cols), dtype=bool) if name.startswith("Crystal") else foliage & green
        cols[mask] = cols[mask]*.43 + np.array(ACCENTS[name])*.57
    return np.clip(cols, 0, 255)


def merge(parts):
    return tuple(np.concatenate(x) for x in zip(*parts))


def axis_rotate(points, angle):
    c, s = math.cos(angle), math.sin(angle)
    matrix = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    return points @ matrix.T


def building(name, load):
    """Place licensed wall, shutter, arch and roof modules on a shared grid."""
    parts = []
    def add(source, size, offset, angle=0, mirror=False):
        points, cols = load(source)
        pts = normalized(points)
        dimensions = np.ptp(pts, axis=(0, 1))
        pts *= np.array(size) / np.maximum(dimensions, .0001)
        if mirror:
            pts[:, :, 2] *= -1
            pts = pts[:, [0, 2, 1]]
        parts.append((axis_rotate(pts, angle)+offset, cols))

    width, depth, wall = {"Cottage": (5.4, 4.3, 2.7), "Workshop": (6.4, 5.2, 3.2), "RecordsHall": (13.2, 3.5, 3.8)}[name]
    shutter = "wall-wood-window-shutters"
    back_count = 5 if name=="RecordsHall" else 3
    for i in range(back_count):
        x = (i+.5)*width/back_count-width/2
        add(shutter,(.27,wall,width/back_count),[x,0,depth/2],-math.pi/2)
    for side in (-1,1):
        for i in range(2):
            add(shutter,(.27,wall,depth*.5),[side*width/2,0,(i-.5)*depth*.5],math.pi if side<0 else 0)
    if name=="RecordsHall":
        for i in range(4):
            x=(i/3-.5)*width
            add("wall-wood-arch",(.35,wall,.55),[x,0,-depth/2])
    else:
        for side in (-1,1):
            add("wall-wood-doorway-square-wide",(.31,wall,width*.21),
                [side*width*.10,0,-depth/2],math.pi/2,side==1)
            add(shutter,(.27,wall,width*.29),[side*width*.355,0,-depth/2],math.pi/2)
    roof = "roof-gable" if name=="Workshop" else "roof-high-gable-detail"
    add(roof,(depth+1.05,wall*.86,width+1.0),[0,wall-.10,0],math.pi/2)
    return merge(parts)


def gateway(triangles, colors):
    half = normalized(triangles)
    half[:, :, 2] -= np.ptp(half[:, :, 2])*.49
    mirror = half[:, [0, 2, 1]].copy()
    mirror[:, :, 2] *= -1
    combined, cols = merge(((half,colors),(mirror,colors)))
    return axis_rotate(combined, math.pi/2), cols


def write_glb(output, objects):
    binary = bytearray()
    views, accessors, mesh, nodes = [], [], [], []
    palette = {}
    image = np.zeros((PALETTE_SIZE, PALETTE_SIZE, 3), dtype=np.uint8)

    def view(payload, target=None):
        while len(binary)%4:
            binary.append(0)
        ref = {"buffer": 0, "byteOffset": len(binary), "byteLength": len(payload)}
        if target:
            ref["target"] = target
        views.append(ref)
        binary.extend(payload)
        return len(views)-1

    def add(array, kind):
        a = {"bufferView": view(array.astype("<f4").tobytes(), 34962),
             "componentType": 5126, "count": len(array), "type": kind}
        if kind == "VEC3":
            a["min"] = array.min(axis=0).tolist()
            a["max"] = array.max(axis=0).tolist()
        accessors.append(a)
        return len(accessors)-1

    rows=[]
    for index,(name, triangles, cols, source) in enumerate(objects):
        face_normals=np.cross(triangles[:, 1]-triangles[:, 0],triangles[:, 2]-triangles[:, 0])
        lengths=np.linalg.norm(face_normals,axis=1)
        keep=lengths>1e-9
        triangles,cols,face_normals,lengths=(v[keep] for v in (triangles,cols,face_normals,lengths))
        normal=np.repeat(face_normals/lengths[:,None],3,axis=0)
        color_keys=np.rint(cols/22).astype(int)*22
        uv=[]
        for key in map(tuple,color_keys):
            i=palette.setdefault(key,len(palette))
            x,y=(i%16)*CELL,(i//16)*CELL
            if y+CELL>PALETTE_SIZE:
                raise ValueError("Material palette exceeds 256 swatches")
            image[y:y+CELL,x:x+CELL]=np.clip(key,0,255)
            uv += [((x+2)/PALETTE_SIZE,(y+2)/PALETTE_SIZE)]*3
        xyz=triangles.reshape(-1,3)
        attrs={"POSITION": add(xyz,"VEC3"), "NORMAL": add(normal,"VEC3"), "TEXCOORD_0": add(np.array(uv),"VEC2")}
        mesh.append({"name": name+"Mesh", "primitives": [{"attributes": attrs, "material": 0}]})
        node={"name": name, "mesh": index, "translation": [(index%7)*16,0,(index//7)*15]}
        nodes.append(node)
        rows.append({"name":name,"source":source,"triangles":len(triangles),"metres":np.ptp(xyz,axis=0).round(3).tolist()})
    img=io.BytesIO()
    Image.fromarray(image).save(img,format="PNG")
    texture=view(img.getvalue())
    scene={"asset":{"version":"2.0"},"scene":0,"scenes":[{"nodes":list(range(len(nodes)))}],
           "nodes":nodes,"meshes":mesh,"accessors":accessors,"bufferViews":views,
           "buffers":[{"byteLength":len(binary)}],"images":[{"name":"Blade Forest matte swatches","bufferView":texture,"mimeType":"image/png"}],
           "samplers":[{"magFilter":9728,"minFilter":9728,"wrapS":33071,"wrapT":33071}],
           "textures":[{"source":0,"sampler":0}],"materials":[{"name":"Blade Forest matte palette","pbrMetallicRoughness":{
                "baseColorTexture":{"index":0},"metallicFactor":0,"roughnessFactor":.91}}]}
    raw=json.dumps(scene,separators=(",",":")).encode()
    raw+=b" "*(-len(raw)%4)
    binary+=b"\0"*(-len(binary)%4)
    output.write_bytes(struct.pack("<4sII",b"glTF",2,28+len(raw)+len(binary))
                       +struct.pack("<I4s",len(raw),b"JSON")+raw
                       +struct.pack("<I4s",len(binary),b"BIN\0")+binary)
    output.with_suffix(".json").write_text(json.dumps(rows,indent=2)+"\n")
    return rows


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("asset_root",type=Path)
    parser.add_argument("out",type=Path)
    parser.add_argument("--sample",action="store_true")
    args=parser.parse_args()
    files={p.stem:p for p in args.asset_root.glob("kenney-*/Models/**/*.glb")}
    cache={}
    def load(name):
        if name not in cache:
            cache[name]=gltf(files[name])
        return cache[name]
    review={"Sapling","GoldenOak","TallPine","Bridge","Boulder","MarketStall","Lantern","GateArch","SnowPine","Crystal"}
    objects=[]
    for name,(stem,height) in FAMILY.items():
        if args.sample and name not in review:
            continue
        triangles,cols=load(stem)
        if name in {"GateArch","WinterArch"}:
            triangles,cols=gateway(triangles,cols)
        triangles=normalized(triangles,height)
        objects.append((name,triangles,grade(name,triangles,cols),stem))
    for name in (("Cottage",) if args.sample else ("Cottage","Workshop","RecordsHall")):
        triangles,cols=building(name,load)
        objects.append((name,triangles,grade(name,triangles,cols),"Fantasy Town Kit wall, roof and gable modules"))
    rows=write_glb(args.out,objects)
    print(f"{len(rows)} authored assets, {sum(r['triangles'] for r in rows)} triangles in the sheet")


if __name__=="__main__":
    main()
