{
  description = "ceph-charms dev shell (ceph-proxy: tox pep8 / py3)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
    in
    {
      devShells = forAll (
        pkgs:
        let
          # CI runs ubuntu-latest (24.04) -> python 3.12.
          python = pkgs.python312;
          # Runtime libs for manylinux wheels pip pulls into the tox venvs
          # (cryptography, lxml, cffi, pydantic, ...) and libudev for pyudev.
          libs = with pkgs; [
            stdenv.cc.cc.lib
            zlib
            libffi
            openssl
            libxml2
            libxslt
            systemdLibs
          ];
          osRelease = pkgs.writeText "os-release" ''
            NAME="Ubuntu"
            ID=ubuntu
            VERSION_ID="24.04"
            VERSION_CODENAME=noble
          '';
          # charmhelpers refuses to import unless /etc/os-release says Ubuntu.
          ubuntuTox = pkgs.writeShellScriptBin "utox" ''
            exec ${pkgs.bubblewrap}/bin/bwrap \
              --dev-bind / / \
              --ro-bind ${osRelease} "$(readlink -f /etc/os-release)" \
              -- tox "$@"
          '';
          aptConfigStub = pkgs.writeShellScriptBin "apt-config" "exit 0";
        in
        {
          default = pkgs.mkShell {
            packages = [
              python
              python.pkgs.tox
              python.pkgs.virtualenv
              pkgs.git # zaza / tempest are git requirements
              pkgs.pkg-config
              ubuntuTox
              aptConfigStub
            ]
            ++ libs;

            # test-requirements.txt uses `#egg=tempest;python_version>=...`,
            # which pip >= 25 rejects. Ubuntu 24.04 CI venvs get pip 24.0.
            VIRTUALENV_PIP = "24.0";
            VIRTUALENV_DOWNLOAD = "1";

            # tox 4 passes LD_LIBRARY_PATH through to its envs by default.
            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath libs;

            shellHook = ''
              # mkShell's 1980 epoch breaks building wheels from sdists
              # (netifaces, psutil<2).
              unset SOURCE_DATE_EPOCH
              unset PYTHONPATH
            '';
          };
        }
      );
    };
}
