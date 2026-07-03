#!/usr/bin/env python3
"""graphify query helper — navigate the repo WITHOUT reading files.

Filters graph.json and prints only small, concise results (never the graph),
so context gets ~a few lines instead of whole source files. Use this instead
of grep for "where is X / who calls Y / what does Z use / what's near it".

Usage:
  python graphify-out/q.py <term>            # find nodes (symbol/file/label substring)
  python graphify-out/q.py callers <node>    # what points AT node (callers/importers/refs)
  python graphify-out/q.py uses <node>       # what node points TO (callees/imports)
  python graphify-out/q.py near <node>       # both directions
  python graphify-out/q.py file <path-sub>   # nodes defined in matching files
  python graphify-out/q.py community <node|N># sibling nodes in the same cluster

Each result prints  id  [label]  file:line  (community N)  so you can then
Read the exact file:line if you truly need the source — a targeted read, not a blind grep.
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
GRAPH = os.path.join(HERE, "graph.json")
CAP = 40  # never flood context


def load():
    g = json.load(open(GRAPH))
    nodes = {n["id"]: n for n in g.get("nodes", [])}
    return nodes, g.get("links", []), g.get("built_at_commit", "?")


def loc(n):
    if not n:
        return ""
    return f'{n.get("source_file","?")}:{str(n.get("source_location","")).lstrip("L")}'


def fmt(n):
    return f'{n["id"]}  [{n.get("label","")}]  {loc(n)}  (c{n.get("community","?")})'


def resolve(term, nodes):
    if term in nodes:
        return [term]
    t = term.lower()
    return [nid for nid, n in nodes.items()
            if t in nid.lower()
            or t in str(n.get("label", "")).lower()
            or t in str(n.get("source_file", "")).lower()]


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return
    nodes, links, commit = load()
    cmd = a[0]

    if cmd == "file" and len(a) > 1:
        sub = " ".join(a[1:]).lower()
        hits = [n for n in nodes.values() if sub in str(n.get("source_file", "")).lower()]
        for n in hits[:CAP]:
            print(fmt(n))
        print(f"[{len(hits)} nodes in files matching '{sub}'; showing {min(len(hits),CAP)}] (graph@{commit[:8]})")
        return

    if cmd == "community" and len(a) > 1:
        arg = " ".join(a[1:])
        comm = int(arg) if arg.isdigit() else (nodes[resolve(arg, nodes)[0]].get("community") if resolve(arg, nodes) else None)
        if comm is None:
            print("no match")
            return
        mem = [n for n in nodes.values() if n.get("community") == comm]
        print(f"community {comm}: {len(mem)} nodes")
        for n in mem[:CAP]:
            print(fmt(n))
        return

    if cmd in ("callers", "uses", "near") and len(a) > 1:
        r = resolve(" ".join(a[1:]), nodes)
        if not r:
            print("no match — try a broader term or `q.py <term>` first")
            return
        nid = r[0]
        if len(r) > 1:
            print(f"# using {nid}  (+{len(r)-1} other matches — refine if wrong)")
        ins = [l for l in links if l.get("target") == nid]
        outs = [l for l in links if l.get("source") == nid]

        def show(lst, title, key):
            print(f"-- {title} ({len(lst)}) --")
            for l in lst[:CAP]:
                o = nodes.get(l.get(key), {})
                print(f'  {l.get("relation","?"):<12} {o.get("id", l.get(key))}  {loc(o)}')
        if cmd in ("callers", "near"):
            show(ins, "CALLERS (point at it)", "source")
        if cmd in ("uses", "near"):
            show(outs, "USES (it points to)", "target")
        return

    # default: node search
    term = " ".join(a)
    hits = resolve(term, nodes)
    for nid in hits[:CAP]:
        print(fmt(nodes[nid]))
    print(f"[{len(hits)} matches for '{term}'; showing {min(len(hits),CAP)}] (graph@{commit[:8]})")


if __name__ == "__main__":
    main()
