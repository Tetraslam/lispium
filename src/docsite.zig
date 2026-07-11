//! Static documentation site generator. Renders the shared docs table
//! (src/docs.zig) as a single self-contained HTML page with client-side
//! search. Regenerate with: lispium docs --html > docs/index.html

const std = @import("std");
const docs_table = @import("docs.zig");
const build_options = @import("build_options");

fn writeEscaped(writer: *std.Io.Writer, text: []const u8) !void {
    for (text) |c| {
        switch (c) {
            '<' => try writer.writeAll("&lt;"),
            '>' => try writer.writeAll("&gt;"),
            '&' => try writer.writeAll("&amp;"),
            '"' => try writer.writeAll("&quot;"),
            else => try writer.writeAll(&[_]u8{c}),
        }
    }
}

pub fn writeHtml(writer: *std.Io.Writer) !void {
    try writer.print(
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<title>Lispium {s} - Function Reference</title>
        \\<style>
        \\  :root {{ --bg: #16161d; --fg: #dcd7ba; --dim: #727169; --accent: #7e9cd8; --card: #1f1f28; --code: #2a2a37; }}
        \\  * {{ box-sizing: border-box; }}
        \\  body {{ margin: 0; font: 16px/1.6 -apple-system, "Segoe UI", sans-serif; background: var(--bg); color: var(--fg); }}
        \\  header {{ padding: 2.5rem 1.5rem 1rem; max-width: 60rem; margin: 0 auto; }}
        \\  h1 {{ margin: 0 0 .25rem; font-size: 1.8rem; }} h1 a {{ color: var(--fg); text-decoration: none; }}
        \\  .sub {{ color: var(--dim); margin-bottom: 1rem; }}
        \\  .sub a {{ color: var(--accent); }}
        \\  main {{ max-width: 60rem; margin: 0 auto; padding: 0 1.5rem 4rem; }}
        \\  #search {{ width: 100%; padding: .6rem .9rem; font-size: 1rem; border-radius: 8px; border: 1px solid var(--code);
        \\             background: var(--card); color: var(--fg); margin-bottom: 1.5rem; }}
        \\  .entry {{ background: var(--card); border-radius: 10px; padding: .9rem 1.1rem; margin-bottom: .75rem; }}
        \\  .sig {{ font-family: ui-monospace, "JetBrains Mono", monospace; color: var(--accent); font-weight: 600; }}
        \\  .summary {{ margin: .3rem 0 0; }}
        \\  .example {{ margin: .5rem 0 0; font-family: ui-monospace, monospace; font-size: .9rem;
        \\              background: var(--code); border-radius: 6px; padding: .45rem .7rem; color: #98bb6c; overflow-x: auto; white-space: pre; }}
        \\  .count {{ color: var(--dim); font-size: .9rem; margin-bottom: 1rem; }}
        \\</style>
        \\</head>
        \\<body>
        \\<header>
        \\<h1><a href="https://github.com/Tetraslam/lispium">Lispium</a> Function Reference</h1>
        \\<div class="sub">v{s} &middot; every builtin and special form &middot;
        \\<a href="playground/">try it in the playground</a> &middot;
        \\<a href="https://github.com/Tetraslam/lispium">GitHub</a></div>
        \\</header>
        \\<main>
        \\<input id="search" type="search" placeholder="Filter: diff, matrix, rational, macro..." autofocus>
        \\<div class="count"><span id="shown">0</span> entries</div>
        \\<div id="entries">
        \\
    , .{ build_options.version, build_options.version });

    for (docs_table.docs) |doc| {
        try writer.writeAll("<div class=\"entry\" data-name=\"");
        try writeEscaped(writer, doc.name);
        try writer.writeAll("\"><div class=\"sig\">");
        try writeEscaped(writer, doc.signature);
        try writer.writeAll("</div><div class=\"summary\">");
        try writeEscaped(writer, doc.summary);
        try writer.writeAll(".</div>");
        if (doc.example) |ex| {
            try writer.writeAll("<div class=\"example\">");
            try writeEscaped(writer, ex);
            try writer.writeAll("</div>");
        }
        try writer.writeAll("</div>\n");
    }

    try writer.writeAll(
        \\</div>
        \\</main>
        \\<script>
        \\const search = document.getElementById('search');
        \\const entries = [...document.querySelectorAll('.entry')];
        \\const shown = document.getElementById('shown');
        \\function refresh() {
        \\  const q = search.value.toLowerCase();
        \\  let n = 0;
        \\  for (const e of entries) {
        \\    const hit = !q || e.textContent.toLowerCase().includes(q) || e.dataset.name.toLowerCase().includes(q);
        \\    e.style.display = hit ? '' : 'none';
        \\    if (hit) n++;
        \\  }
        \\  shown.textContent = n;
        \\}
        \\search.addEventListener('input', refresh);
        \\refresh();
        \\</script>
        \\</body>
        \\</html>
        \\
    );
}
