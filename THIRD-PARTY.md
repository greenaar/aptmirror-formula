# Third-party material

**This repository as a whole is GPL-2.0**, not CC0 like the other formulas
in this set, because it embeds a modified copy of `apt-mirror`.

## `files/apt-mirror`

- **License:** GPL-2.0
- **Copyright:** the apt-mirror authors
- **Upstream:** <https://github.com/apt-mirror/apt-mirror>
- Vendored from master at commit
  `2ef8e73f700c0989f7f8e4347fbf76cf3b8ce132` (2023-11-01) and modified
  locally. Provenance, pristine checksum, and the full list of local
  changes are in [UPSTREAM.md](UPSTREAM.md) and the script header.

The full GPL-2.0 text is in [LICENSE](LICENSE).

## Why this repo isn't CC0

The vendored script isn't merely templated alongside the formula — it's
modified and distributed as part of it, which makes this repository a
derivative work of a GPL-2.0 program. The states, templates, and docs
here are therefore also GPL-2.0.

If you want a public-domain aptmirror formula, drop `files/apt-mirror`
and have `install.sls` use the distribution's `apt-mirror` package (or
fetch the script at apply time), then relicense what remains.
