This is a pandoc filter designed to be used with [Pandoc Typst PDF (`ptp`)](https://github.com/cskeeters/ptp) that enables acronyms.

```markdown
---
title: Acronym Demo
author: Chad Skeeters
template: school-paper-local.typ
acronyms:
  LAN: Local Area Network
  WAN: Wide Area Network
filters:
  - pandoc-acronyms/0.1.0/acronyms.lua
---

Devices on a +LAN access the +WAN via a gateway, not a router, on most home networks.
```

# Usage

```sh
ptp doc.md
```

## Manual

If you are not using `ptp`, you can run the filter with:

```sh
pandoc -L pandoc-acronyms/0.1.0/acronyms.lua doc.md -o doc.typ
typst compile doc.typ
```

# Installation

```
mkdir -p ~/.pandoc/filters/pandoc-acronyms
cd ~/.pandoc/filters/pandoc-acronyms
git clone https://github.com/cskeeters/pandoc-acronyms 0.1.0
cd 0.1.0
git switch --detach v0.1.0
```
