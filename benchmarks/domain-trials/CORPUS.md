# Domain trial corpus

`v1` is deliberately offline by default. Each case stores a small, immutable raw extract
and a receipt with the public source URL, query, retrieval timestamp, checksum, terms
note, source vintage, and transformations. A live canary may confirm endpoint reachability,
but it never updates or becomes the golden expected result.
