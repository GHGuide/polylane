#!/usr/bin/env python3
"""graphify query helper — navigate the repo WITHOUT reading files.

Filters graph.json and prints only small, concise results (never the graph),
so context gets a few lines instead of whole source files. Use this instead
of grep for "where is X / who calls Y / what does Z use / what's near it".

Usage:
  python graphify-out/q.py <term>            # find nodes (symbol/file/label substring)
  python graphify-out/q.py callers <node>    # what points AT node (callers/importers/refs)
  python graphify-out/q.py uses <node>       # what node points TO (callees/imports)
  python graphify-out/q.py near <node>       # both directions
  python graphify-out/q.py file <path-sub>   # nodes defined in matching files
  python graphify-out/q.py community <node|N># sibling nodes in the same cluster

Flags (any position):
  --json           machine-readable JSON instead of text
  --graph PATH     graph.json to query (default: graph.json beside this script)
  --cap N          max results to print (default 40)

Each result prints  id  [label]  file:line  (cN)  so you can then Read the exact
file:line if you truly need the source — a targeted read, not a blind grep.

Matching: exact id first, then case-insensitive substring over id/label/file.
Zero hits → a fuzzy "did you mean:" list (max 5) so typos self-correct.
"""
import argparse
import difflib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_GRAPH = os.path.join(HERE, "graph.json")
DEFAULT_CAP = 40
COMMANDS = ("callers", "uses", "near", "file", "community")


def die(msg, code=1):
    print(msg, file=sys.stderr)
    sys.exit(code)


def load(path):
    if not os.path.isfile(path):
        die(f"graph.json not found at {path}\n"
            f"Run /graphify-auto to build it (free, no LLM), then retry.")
    try:
        with open(path) as f:
            g = json.load(f)
    except (OSError, ValueError) as e:
        die(f"could not read graph at {path}: {e}")
    try:
        nodes = {n["id"]: n for n in g.get("nodes", [])}
        links = g.get("links", [])
        commit = g.get("built_at_commit", "?")
    except (AttributeError, TypeError, KeyError):
        die(f"graph at {path} has unexpected shape "
            f"(expected object with 'nodes'/'links'). "
            f"Rebuild with /graphify-auto.")
    return nodes, links, commit


def loc(n):
    if not n:
        return ""
    return f'{n.get("source_file","?")}:{str(n.get("source_location","")).lstrip("L")}'


def comm(n):
    return f'c{n.get("community","?")}' if n else "c?"


def fmt(n):
    return f'{n["id"]}  [{n.get("label","")}]  {loc(n)}  ({comm(n)})'


def node_dict(n):
    return {
        "id": n["id"],
        "label": n.get("label", ""),
        "file": n.get("source_file"),
        "line": str(n.get("source_location", "")).lstrip("L"),
        "community": n.get("community"),
    }


def edge_dict(link, other, key):
    return {
        "relation": link.get("relation", "?"),
        "id": other.get("id", link.get(key)),
        "file": other.get("source_file"),
        "line": str(other.get("source_location", "")).lstrip("L"),
        "community": other.get("community"),
    }


def resolve(term, nodes):
    if term in nodes:
        return [term]
    t = term.lower()
    return [nid for nid, n in nodes.items()
            if t in nid.lower()
            or t in str(n.get("label", "")).lower()
            or t in str(n.get("source_file", "")).lower()]


def suggest(term, nodes, limit=5):
    """Fuzzy 'did you mean' candidates for a term with zero substring hits."""
    t = term.lower()
    cands = {}  # lowercase candidate string -> node id
    for nid in nodes:
        cands.setdefault(nid.lower(), nid)
        tail = nid.replace("::", ".").replace("/", ".").rsplit(".", 1)[-1]
        cands.setdefault(tail.lower(), nid)
    close = difflib.get_close_matches(t, cands, n=limit * 3, cutoff=0.5)
    out = []
    for c in close:
        nid = cands[c]
        if nid not in out:
            out.append(nid)
        if len(out) >= limit:
            break
    return out


def miss(term, nodes, as_json, text_msg):
    """Report a resolve miss: JSON stays parseable, text gets suggestions."""
    sugg = suggest(term, nodes)
    if as_json:
        emit_json({"error": f"no match for '{term}'", "did_you_mean": sugg})
        sys.exit(1)
    extra = f"\ndid you mean: {', '.join(sugg)}" if sugg else ""
    die(text_msg + extra)


def emit_json(obj):
    print(json.dumps(obj, indent=2))


def cmd_search(term, nodes, commit, cap, as_json):
    hits = resolve(term, nodes)
    shown = hits[:cap]
    sugg = suggest(term, nodes) if not hits else []
    if as_json:
        obj = {"query": term, "count": len(hits),
               "results": [node_dict(nodes[h]) for h in shown]}
        if sugg:
            obj["did_you_mean"] = sugg
        emit_json(obj)
        return
    for h in shown:
        print(fmt(nodes[h]))
    print(f"[{len(hits)} matches for '{term}'; showing {len(shown)}] (graph@{commit[:8]})")
    if sugg:
        print(f"did you mean: {', '.join(sugg)}")


def cmd_file(sub, nodes, commit, cap, as_json):
    hits = [n for n in nodes.values() if sub in str(n.get("source_file", "")).lower()]
    shown = hits[:cap]
    if as_json:
        emit_json({"pattern": sub, "count": len(hits),
                   "results": [node_dict(n) for n in shown]})
        return
    for n in shown:
        print(fmt(n))
    print(f"[{len(hits)} nodes in files matching '{sub}'; showing {len(shown)}] (graph@{commit[:8]})")


def cmd_community(ref, nodes, commit, cap, as_json):
    if ref.isdigit():
        target = int(ref)
    else:
        r = resolve(ref, nodes)
        if not r:
            miss(ref, nodes, as_json,
                 "no match — try `q.py <term>` first, or pass a community number")
        target = nodes[r[0]].get("community")
    if target is None:
        if as_json:
            emit_json({"error": "no community found for that node"})
            sys.exit(1)
        die("no community found for that node")
    mem = [n for n in nodes.values() if n.get("community") == target]
    shown = mem[:cap]
    if as_json:
        emit_json({"community": target, "count": len(mem),
                   "results": [node_dict(n) for n in shown]})
        return
    print(f"community {target}: {len(mem)} nodes")
    for n in shown:
        print(fmt(n))


def cmd_edges(cmd, ref, nodes, links, commit, cap, as_json):
    r = resolve(ref, nodes)
    if not r:
        miss(ref, nodes, as_json,
             "no match — try a broader term or `q.py <term>` first")
    nid = r[0]
    ins = [l for l in links if l.get("target") == nid]
    outs = [l for l in links if l.get("source") == nid]

    if as_json:
        obj = {"node": nid}
        if cmd in ("callers", "near"):
            obj["callers"] = [edge_dict(l, nodes.get(l.get("source"), {}), "source")
                              for l in ins[:cap]]
        if cmd in ("uses", "near"):
            obj["uses"] = [edge_dict(l, nodes.get(l.get("target"), {}), "target")
                           for l in outs[:cap]]
        emit_json(obj)
        return

    if len(r) > 1:
        print(f"# using {nid}  (+{len(r)-1} other matches — refine if wrong)")

    def show(lst, title, key):
        print(f"-- {title} ({len(lst)}) --")
        for l in lst[:cap]:
            o = nodes.get(l.get(key), {})
            print(f'  {l.get("relation","?"):<12} {o.get("id", l.get(key))}  {loc(o)}  ({comm(o)})')

    if cmd in ("callers", "near"):
        show(ins, "CALLERS (point at it)", "source")
    if cmd in ("uses", "near"):
        show(outs, "USES (it points to)", "target")


def build_parser():
    p = argparse.ArgumentParser(
        prog="q.py", add_help=True,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=__doc__)
    p.add_argument("--json", action="store_true", dest="as_json",
                   help="machine-readable JSON output")
    p.add_argument("--graph", default=DEFAULT_GRAPH,
                   help="path to graph.json (default: beside this script)")
    p.add_argument("--cap", type=int, default=DEFAULT_CAP,
                   help="max results to print (default 40)")
    p.add_argument("args", nargs=argparse.REMAINDER,
                   help="<term> | callers|uses|near|file|community <arg>")
    return p


def main():
    parser = build_parser()
    opts = parser.parse_args()
    pos = opts.args
    if not pos:
        print(__doc__)
        return

    nodes, links, commit = load(opts.graph)
    cmd = pos[0]

    if cmd in COMMANDS:
        arg = " ".join(pos[1:]).strip()
        if not arg:
            die(f"`{cmd}` needs an argument, e.g. `q.py {cmd} <node>`")
        if cmd == "file":
            cmd_file(arg.lower(), nodes, commit, opts.cap, opts.as_json)
        elif cmd == "community":
            cmd_community(arg, nodes, commit, opts.cap, opts.as_json)
        else:
            cmd_edges(cmd, arg, nodes, links, commit, opts.cap, opts.as_json)
        return

    # default: node search (contract: `q.py <symbol>`)
    cmd_search(" ".join(pos), nodes, commit, opts.cap, opts.as_json)


if __name__ == "__main__":
    main()
