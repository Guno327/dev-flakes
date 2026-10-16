{
  description = "various sunbeam dev shells";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      osRelease = pkgs.writeText "os-release" ''
        NAME="Ubuntu"
        ID=ubuntu
        VERSION_ID="24.04"
      '';
      tox = pkgs.writeShellScriptBin "tox" ''
        exec ${pkgs.bubblewrap}/bin/bwrap --dev-bind / / \
          --ro-bind ${osRelease} "$(readlink -f /etc/os-release)" \
          ${pkgs.python312Packages.tox}/bin/tox "$@"
      '';
      fakeSnapctl = pkgs.writeShellScript "snapctl" ''
        echo "error: snapctl: cannot run outside of a snap" >&2
        exit 1
      '';
      snapTox = pkgs.writeShellScriptBin "tox" ''
        exec ${pkgs.bubblewrap}/bin/bwrap --dev-bind / / \
          --tmpfs /usr/bin \
          --ro-bind ${pkgs.coreutils}/bin/env /usr/bin/env \
          --ro-bind ${fakeSnapctl} /usr/bin/snapctl \
          ${pkgs.python312Packages.tox}/bin/tox "$@"
      '';
      aptConfig = pkgs.writeShellScriptBin "apt-config" "exit 0";
    in
    {
      devShells.${system} = {
        sunbeam-charms = pkgs.mkShell {
          packages = [
            pkgs.python312
            tox
            pkgs.git-review
            aptConfig
          ];
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
          ];
        };
        snap-openstack-hypervisor = pkgs.mkShell {
          packages = with pkgs; [
            python314
            uv
            tox
            libvirt
            pkg-config
          ];
          # uv's downloaded Pythons are not NixOS-friendly; use the Nix one.
          UV_PYTHON_DOWNLOADS = "never";
          UV_PYTHON = "${pkgs.python314}/bin/python3.14";
        };
        snap-openstack = pkgs.mkShell {
          packages = [
            pkgs.python312
            pkgs.uv
            snapTox
          ];
          UV_PYTHON_DOWNLOADS = "never";
          UV_PYTHON = "${pkgs.python312}/bin/python3.12";
          UV_PYTHON_PREFERENCE = "only-system";
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
            pkgs.openssl
            pkgs.libffi
          ];
          # pip-installed ruff (pep8/fmt envs) runs via nix-ld
          NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
          ];
          NIX_LD = pkgs.lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
        };
        snap-cinder-volume = pkgs.mkShell {
          packages = [
            pkgs.python312
            pkgs.python314
            pkgs.python312Packages.tox
            pkgs.uv
          ];
          # No UV_PYTHON pin: uv picks 3.12 or 3.14 from requires-python per branch.
          UV_PYTHON_DOWNLOADS = "never";
          UV_PYTHON_PREFERENCE = "only-system";
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
            pkgs.openssl
            pkgs.libffi
          ];
          NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
          ];
          NIX_LD = pkgs.lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
        };
      };
    };
}
