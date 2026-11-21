"""Generate src/shared/EconomyConfig.luau from economy_params.json (the single source of truth).

    python3 gen_luau.py            # writes the file, prints length:adler32
    python3 gen_luau.py --check    # exit 1 if the committed file is out of date
"""
import json, os, re, sys, zlib

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "economy_params.json")
DST = os.path.abspath(os.path.join(HERE, "..", "..", "src", "shared", "EconomyConfig.luau"))
IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def lua(v, ind=0):
    pad = "\t" * ind
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        if isinstance(v, float) and v.is_integer() and abs(v) < 1e15:
            return str(int(v))
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list):
        if not v:
            return "{}"
        simple = all(not isinstance(x, (dict, list)) for x in v)
        if simple:
            return "{ " + ", ".join(lua(x) for x in v) + " }"
        return "{\n" + "".join(f"{pad}\t{lua(x, ind + 1)},\n" for x in v) + pad + "}"
    if isinstance(v, dict):
        items = [(k, x) for k, x in v.items() if not k.startswith("_")]
        if not items:
            return "{}"
        def key(k): return k if IDENT.match(k) else f"[{json.dumps(k)}]"
        flat = all(not isinstance(x, (dict, list)) for _, x in items) and len(items) <= 8
        if flat:
            return "{ " + ", ".join(f"{key(k)} = {lua(x)}" for k, x in items) + " }"
        return "{\n" + "".join(f"{pad}\t{key(k)} = {lua(x, ind + 1)},\n" for k, x in items) + pad + "}"
    raise TypeError(type(v))


def build():
    P = json.load(open(SRC))
    body = lua(P)
    return ("-- EconomyConfig (M1): GENERATED from tools/econsim/economy_params.json by tools/econsim/gen_luau.py.\n"
            "-- Do not edit by hand: change the JSON, re-run gen_luau.py and the simulator (tools/econsim/run_all.sh).\n"
            "-- Every M1 economy number (pools, caps, prices, upgrades, altars, gates, bosses) lives here.\n"
            "return " + body + "\n")


if __name__ == "__main__":
    text = build()
    if "--check" in sys.argv:
        cur = open(DST).read() if os.path.exists(DST) else ""
        sys.exit(0 if cur == text else 1)
    open(DST, "w").write(text)
    d = text.encode()
    print(DST, f"{len(d)}:{zlib.adler32(d)}")
