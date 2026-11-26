#!/usr/bin/env python3
"""Relaxed or gripping hands for VARCO characters, baked into the bind pose of the GLB.

VARCO's auto-rig has no finger bones: every hand is one rigid "Hand" bone, and the mesh is
modelled in a T-pose with the fingers straight and spread and the thumb stuck out. Whatever the
arm does, the hand stays a flat, open paddle, which reads as tense and unnatural (a hand at rest
curls: the fingers flex a little more from the index to the little finger - the "finger cascade" -
and sit together, the thumb lies along the index). There is no bone to pose, so this reshapes the
hand mesh itself, in the bind pose, where it is skinned rigidly to the Hand bone:

  - fingers: every vertex past the knuckle line is bent toward the palm like a jointed finger
    (most of the curl at the knuckle and the middle joint, little at the tip), more on the little
    finger side than on the index side, and drawn a little together;
  - thumb: found from its tip (a separate prong past the knuckle line) and the geodesic distance
    from it over the mesh; it turns about its root toward the palm and the index finger;
  - "grip": a fist (the weapon hand) - the same with a much stronger curl and the thumb wrapped
    over the fingers.

Positions, normals and tangents are rewritten in place in the GLB's buffer; nothing else changes
(skin, weights, UVs, animations, materials, textures stay byte-identical).

usage: hand_pose.py IN.glb OUT.glb [--left relaxed|grip|none] [--right relaxed|grip|none]
                    [--plot debug.png]
"""
import heapq
import json
import struct
import sys
from collections import defaultdict

import numpy as np

# finger curl (degrees, whole finger) on the index side and the little finger side
STYLES = {
    "relaxed": {"index": 60.0, "little": 86.0, "together": 0.4, "thumb_flex": 25.0, "thumb_in": 22.0},
    "grip": {"index": 98.0, "little": 112.0, "together": 0.35, "thumb_flex": 48.0, "thumb_in": 30.0},
}
# share of the curl at the base knuckle, the middle joint and the last joint, and where along the
# finger (0 = knuckle line, 1 = fingertip) those joints are
JOINTS = [(0.0, 0.47), (0.45, 0.38), (0.74, 0.15)]
KNUCKLE = 0.43  # knuckle line, as a fraction of the hand's length from the wrist joint

CT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class GLB:
    def __init__(self, path):
        d = open(path, "rb").read()
        n = struct.unpack_from("<I", d, 12)[0]
        self.j = json.loads(d[20:20 + n])
        off = 20 + n
        bl = struct.unpack_from("<I", d, off)[0]
        self.bin = bytearray(d[off + 8:off + 8 + bl])

    def _span(self, i):
        a = self.j["accessors"][i]
        bv = self.j["bufferViews"][a["bufferView"]]
        dt = np.dtype(CT[a["componentType"]])
        nc = NC[a["type"]]
        assert bv.get("byteStride", 0) in (0, dt.itemsize * nc), "interleaved buffers are not handled"
        return bv.get("byteOffset", 0) + a.get("byteOffset", 0), dt, nc, a["count"]

    def read(self, i):
        o, dt, nc, cnt = self._span(i)
        return np.frombuffer(self.bin, dtype=dt, count=cnt * nc, offset=o).reshape(cnt, nc).copy()

    def write(self, i, arr):
        o, dt, nc, cnt = self._span(i)
        assert dt == np.float32 and arr.shape == (cnt, nc)
        b = np.ascontiguousarray(arr, dtype=np.float32).tobytes()
        self.bin[o:o + len(b)] = b
        a = self.j["accessors"][i]
        if "min" in a:
            a["min"] = [float(x) for x in arr.min(0)]
            a["max"] = [float(x) for x in arr.max(0)]

    def save(self, path):
        js = json.dumps(self.j, separators=(",", ":")).encode()
        js += b" " * ((4 - len(js) % 4) % 4)
        bn = bytes(self.bin) + b"\0" * ((4 - len(self.bin) % 4) % 4)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bn)))
            f.write(struct.pack("<II", len(js), 0x4E4F534A))
            f.write(js)
            f.write(struct.pack("<II", len(bn), 0x004E4942))
            f.write(bn)


def rot(axis, ang):
    """Rotation matrices (n, 3, 3) about unit axes (n, 3) or one axis (3,), by angles (n,) radians."""
    ang = np.asarray(ang, dtype=np.float64)
    axis = np.broadcast_to(np.asarray(axis, dtype=np.float64), ang.shape + (3,))
    x, y, z = axis[..., 0], axis[..., 1], axis[..., 2]
    c, s = np.cos(ang), np.sin(ang)
    C = 1 - c
    return np.stack([
        np.stack([c + x * x * C, x * y * C - z * s, x * z * C + y * s], -1),
        np.stack([y * x * C + z * s, c + y * y * C, y * z * C - x * s], -1),
        np.stack([z * x * C - y * s, z * y * C + x * s, c + z * z * C], -1)], -2)


def smooth(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def geodesic(seeds, verts, P, tris):
    """Distance over the mesh surface from the seed vertices (vertices at the same spot - UV seams -
    are one node)."""
    node = {int(v): tuple(np.round(P[v] / 1e-5).astype(np.int64)) for v in verts}
    vs = set(verts.tolist())
    adj = defaultdict(dict)
    for t in tris:
        for a in range(3):
            u, w = int(t[a]), int(t[(a + 1) % 3])
            if u in vs and w in vs:
                d = float(np.linalg.norm(P[u] - P[w]))
                ku, kw = node[u], node[w]
                if ku != kw:
                    adj[ku][kw] = min(adj[ku].get(kw, 9.0), d)
                    adj[kw][ku] = adj[ku][kw]
    dist = {}
    heap = [(0.0, node[int(s)]) for s in seeds]
    while heap:
        d, k = heapq.heappop(heap)
        if k in dist:
            continue
        dist[k] = d
        for k2, e in adj[k].items():
            if k2 not in dist:
                heapq.heappush(heap, (d + e, k2))
    return np.array([dist.get(node[int(v)], np.inf) for v in verts])


def components(verts, P, tris):
    vs = set(verts.tolist())
    node = {int(v): tuple(np.round(P[v] / 1e-5).astype(np.int64)) for v in verts}
    adj = defaultdict(set)
    for t in tris:
        for a in range(3):
            u, w = int(t[a]), int(t[(a + 1) % 3])
            if u in vs and w in vs:
                adj[node[u]].add(node[w])
                adj[node[w]].add(node[u])
    by = defaultdict(list)
    for v in verts:
        by[node[int(v)]].append(int(v))
    seen, out = set(), []
    for k0 in by:
        if k0 in seen:
            continue
        seen.add(k0)
        stack, comp = [k0], []
        while stack:
            k = stack.pop()
            comp += by[k]
            for k2 in adj[k]:
                if k2 not in seen:
                    seen.add(k2)
                    stack.append(k2)
        out.append(np.array(comp))
    return sorted(out, key=len, reverse=True)


def pose_hand(P, N, T, J, W, tris, joint, bind, style, log):
    st = STYLES[style]
    hw = (W * (J == joint)).sum(1)
    O = bind[:3, 3]
    near = np.linalg.norm(P - O, axis=1) < 0.2  # (some outfits weight far-off parts to the hand)
    verts = np.where((hw > 0.02) & near)[0]
    core = np.where((hw > 0.5) & near)[0]
    a = bind[:3, 1] / np.linalg.norm(bind[:3, 1])          # along the hand, toward the fingertips
    n = bind[:3, 2] / np.linalg.norm(bind[:3, 2])          # back of the hand (the palm faces -n)
    b = np.cross(n, a)
    s = (P - O) @ a
    L = s[core].max()
    sk = KNUCKLE * L
    # the thumb tip is the small prong past the knuckle line; it sets which side is the thumb's
    comps = components(core[s[core] > 0.45 * L], P, tris)
    tips = [c for c in comps[1:] if len(c) < 0.4 * len(comps[0])]
    if not tips:
        raise SystemExit("no thumb tip found")
    tip = max(tips, key=len)
    if (P[tip] - O).mean(0) @ b < 0:
        b = -b                                              # +b: toward the thumb
    w = (P - O) @ b
    h = (P - O) @ n
    # thumb: geodesic distance from its tip, fading out toward its root
    g = geodesic(tip, verts, P, tris)
    reach = float(np.linalg.norm(P[tip].mean(0) - O))
    mt = np.zeros(len(P))
    mt[verts] = 1.0 - smooth((g / reach - 0.45) / 0.35)
    # fingers: past the knuckle line, minus the thumb
    fing = core[(s[core] > sk) & (mt[core] < 0.5)]
    wmin, wmax = np.percentile(w[fing], 3), np.percentile(w[fing], 97)
    hc = np.median(h[fing[s[fing] < sk + 0.15 * L]])
    Lf = s[fing].max() - sk
    wc = 0.5 * (wmin + wmax)
    log("  hand L=%.3f knuckle s=%.3f finger length %.3f band w %.3f..%.3f thumb verts %d"
        % (L, sk, Lf, wmin, wmax, int((mt > 0.5).sum())))

    newP, newN, newT = P.copy(), N.copy(), T.copy()
    idx = verts[s[verts] > sk]
    u = np.clip((s[idx] - sk) / Lf, 0.0, 1.2)
    cas = smooth((wmax - w[idx]) / max(wmax - wmin, 1e-6))  # 0 index side .. 1 little finger side
    theta = np.radians(st["index"] + (st["little"] - st["index"]) * cas)

    def curl(x):  # share of the curl reached at finger position x (soft joints)
        return sum(share * smooth((x - at) / 0.1 + 0.5) for at, share in JOINTS)
    # finger centreline in the (along, back) plane, integrated from the knuckle line
    steps = 48
    cs = np.zeros(len(idx))
    ch = np.zeros(len(idx))
    for k in range(steps):
        x = u * (k + 0.5) / steps
        ph = theta * curl(x)
        cs += np.cos(ph) * (u / steps) * Lf
        ch -= np.sin(ph) * (u / steps) * Lf
    phi = theta * curl(u)
    d = h[idx] - hc
    s_new = sk + cs + d * np.sin(phi)
    h_new = hc + ch + d * np.cos(phi)
    w_new = wc + (w[idx] - wc) * (1.0 - st["together"] * smooth(u * 2.0))
    fingerP = O + np.outer(s_new, a) + np.outer(h_new, n) + np.outer(w_new, b)
    bend_axis = np.cross(a, -n)
    bend_axis /= np.linalg.norm(bend_axis)
    R = rot(bend_axis, phi)  # turns `a` toward -n (into the palm)
    m = (1.0 - mt[idx])[:, None]
    newP[idx] = P[idx] * (1 - m) + fingerP * m
    Rn = np.einsum("nij,nj->ni", R, N[idx])
    Rt = np.einsum("nij,nj->ni", R, T[idx, :3])
    newN[idx] = N[idx] * (1 - m) + Rn * m
    newT[idx, :3] = T[idx, :3] * (1 - m) + Rt * m

    # thumb: about its root, into the palm and toward the index finger
    th = verts[mt[verts] > 0.001]
    root_band = verts[(g / reach > 0.68) & (g / reach < 0.85)]
    root = P[root_band].mean(0) if len(root_band) else O
    tdir = P[tip].mean(0) - root
    tdir /= np.linalg.norm(tdir)
    flex_axis = np.cross(tdir, -n)
    flex_axis /= np.linalg.norm(flex_axis)
    k = mt[th]
    Rf = rot(flex_axis, np.radians(st["thumb_flex"]) * k)
    in_axis = np.cross(tdir, a)
    in_axis /= np.linalg.norm(in_axis)
    Ri = rot(in_axis, np.radians(st["thumb_in"]) * k)   # toward the fingers' direction
    Rth = np.einsum("nij,njk->nik", Ri, Rf)
    newP[th] = root + np.einsum("nij,nj->ni", Rth, newP[th] - root)
    newN[th] = np.einsum("nij,nj->ni", Rth, newN[th])
    newT[th, :3] = np.einsum("nij,nj->ni", Rth, newT[th, :3])
    newN[verts] /= np.linalg.norm(newN[verts], axis=1, keepdims=True)
    tl = np.linalg.norm(newT[verts, :3], axis=1, keepdims=True)
    newT[verts, :3] /= np.where(tl > 0, tl, 1)
    # where a fist holds a handle: just past the knuckle line, under the palm, mid-width; the
    # handle runs across the hand (along b); in the Hand bone's own space for the weapon attachment
    hole = O + a * (sk + 0.06 * L) + n * (hc - 0.022 * L / 0.104) + b * wc
    inv = np.linalg.inv(bind)
    grip = dict(pos=(inv @ np.append(hole, 1.0))[:3], thumb_axis=inv[:3, :3] @ b)
    log("  grip centre (bone space) %s, toward the thumb %s" % (np.round(grip["pos"], 4), np.round(grip["thumb_axis"], 3)))
    return newP, newN, newT, dict(verts=verts, mt=mt, fing=fing, O=O, a=a, n=n, b=b, grip=grip)


def main():
    args = sys.argv[1:]
    src, dst = args[0], args[1]
    opts = {"--left": "relaxed", "--right": "relaxed", "--plot": None}
    for i in range(2, len(args), 2):
        opts[args[i]] = args[i + 1]
    g = GLB(src)
    pr = g.j["meshes"][0]["primitives"][0]
    at = pr["attributes"]
    P = g.read(at["POSITION"]).astype(np.float64)
    N = g.read(at["NORMAL"]).astype(np.float64)
    T = g.read(at["TANGENT"]).astype(np.float64)
    J = g.read(at["JOINTS_0"])
    W = g.read(at["WEIGHTS_0"])
    tris = g.read(pr["indices"]).reshape(-1, 3)
    skin = g.j["skins"][0]
    names = [g.j["nodes"][k]["name"] for k in skin["joints"]]
    ibm = g.read(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1).astype(np.float64)
    dbg = {}
    for side, key in (("LeftHand", "--left"), ("RightHand", "--right")):
        style = opts[key]
        if style == "none":
            continue
        print(side, style)
        jt = names.index(side)
        P, N, T, dbg[side] = pose_hand(P, N, T, J, W, tris, jt, np.linalg.inv(ibm[jt]), style, print)
    g.write(at["POSITION"], P.astype(np.float32))
    g.write(at["NORMAL"], N.astype(np.float32))
    g.write(at["TANGENT"], T.astype(np.float32))
    g.save(dst)
    print("WROTE", dst)
    if opts["--plot"]:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        P0 = GLB(src).read(at["POSITION"])
        fig, ax = plt.subplots(len(dbg), 3, figsize=(15, 5 * len(dbg)), squeeze=False)
        for r, (side, d) in enumerate(dbg.items()):
            v = d["verts"]
            for c, (Q, ttl) in enumerate(((P0, "before"), (P, "after"))):
                ax[r][c].scatter(Q[v] @ d["a"], Q[v] @ d["n"], c=d["mt"][v], s=5, cmap="coolwarm")
                ax[r][c].set_aspect("equal")
                ax[r][c].set_title(side + " side view (along, back) " + ttl)
            ax[r][2].scatter(P[v] @ d["a"], P[v] @ d["b"], c=d["mt"][v], s=5, cmap="coolwarm")
            ax[r][2].set_aspect("equal")
            ax[r][2].set_title("after, top (along, thumb side)")
        plt.tight_layout()
        plt.savefig(opts["--plot"], dpi=60)


if __name__ == "__main__":
    main()
