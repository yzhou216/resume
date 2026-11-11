{
  description = "Yiyu Zhou's resume";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs@{ flake-parts, systems, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;

      perSystem =
        { pkgs, ... }:
        with pkgs;
        let
          texPackages =
            packages: with packages; [
              enumitem
              geometry
              hyperref
              lm
              titlesec
            ];

          htmlTex = texliveBasic.withPackages (
            packages:
            texPackages packages
            ++ (with packages; [
              kastrup
              luacode
              luatexbase
              luaxml
              make4ht
              tex4ht
            ])
          );

          # Tectonic normally downloads its resource bundle at build time,
          # which the Nix sandbox forbids.  Instead, flatten a TeX Live tree
          # from nixpkgs into a local directory bundle.  Tectonic looks files
          # up by base name, so the first file found under a given name wins.
          tectonicBundle =
            let
              tree = texliveBasic.withPackages texPackages;
            in
            runCommand "tectonic-bundle" { } ''
              mkdir -p "$out"
              find -L ${tree}/share/texmf-var ${tree}/share/texmf \
                ${texlive.pkgs.xetex.tex} \
                -type f -not -name language.dat -print0 |
                while IFS= read -r -d "" file; do
                  name="''${file##*/}"
                  [ -e "$out/$name" ] || ln -s "$file" "$out/$name"
                done

              # Only English hyphenation patterns are installed
              cat > "$out/language.dat" <<'EOF'
              english hyphen.tex
              =usenglish
              =USenglish
              =american
              nohyphenation zerohyph.tex
              EOF

              # expl3 detects the platform by probing /dev/null, which
              # Tectonic refuses to open because it is an absolute path.
              # Every supported system is Unix, so take that branch directly.
              expl3="$(readlink "$out/expl3-code.tex")"
              rm "$out/expl3-code.tex"
              install -m644 "$expl3" "$out/expl3-code.tex"
              substituteInPlace "$out/expl3-code.tex" \
                --replace-fail '\file_if_exist:nT { /dev/null }' '\use:n'

              echo '\input xelatex.ini' > "$out/tectonic-format-latex.tex"
              printf '%s' "$out" | sha256sum | cut -c1-64 > "$out/SHA256SUM"
            '';

          src = lib.fileset.toSource {
            root = ./.;
            fileset = lib.fileset.unions [
              ./resume.tex
              ./resume.cfg
            ];
          };

          pdf = stdenvNoCC.mkDerivation {
            name = "resume-pdf";
            inherit src;

            nativeBuildInputs = [ tectonic ];

            # Fonts come from the bundle, but XeTeX still initializes Fontconfig
            env.FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ ]; };

            buildPhase = ''
              runHook preBuild
              export HOME="$TMPDIR"
              tectonic -X compile --bundle ${tectonicBundle} resume.tex
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              install -Dm644 resume.pdf "$out/resume.pdf"
              runHook postInstall
            '';
          };

          html = stdenvNoCC.mkDerivation {
            name = "resume-html";
            inherit src;

            nativeBuildInputs = [ htmlTex ];

            buildPhase = ''
              runHook preBuild
              export HOME="$TMPDIR"
              make4ht --lua --utf8 --config resume.cfg resume.tex
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              install -Dm644 -t "$out" resume.html resume.css
              runHook postInstall
            '';
          };
        in
        {
          packages = {
            inherit pdf html;
            default = symlinkJoin {
              name = "resume";
              paths = [
                pdf
                html
              ];
            };
          };

          devShells.default = mkShellNoCC {
            packages = [
              htmlTex
              tectonic
            ];
          };
        };
    };
}
