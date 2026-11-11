# resume

## Building

```sh
nix build
```

This writes `result/resume.pdf`, `result/resume.html`, and
`result/resume.css`.  Use `nix build .#pdf` or `nix build .#html` to build
only one of them.  The PDF is typeset with Tectonic against a local bundle
assembled from the TeX Live in nixpkgs, so the build needs no network access.
The HTML is produced by make4ht, configured by `resume.cfg`.

For local iteration, `nix develop` provides both toolchains:

```sh
tectonic -X compile resume.tex
make4ht --lua --utf8 --config resume.cfg resume.tex
```

Outside of Nix, Tectonic fetches its own web bundle, so the result can differ
slightly from `nix build`.
