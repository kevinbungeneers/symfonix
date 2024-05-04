{ pkgs, lib, processes }:
let
   procfile = pkgs.writeText "Procfile" (lib.concatStringsSep "\n"
      (lib.mapAttrsToList (name: process: "${name}: exec ${pkgs.writeShellScript name process.exec}")
        processes));

   # Had to wrap overmind so that I could set the root directory. It defaults to the dir where the procfile is located
   # and there's no env var to override this dir value, for some reason.
   # The wrapping also allows me to generate the SSL root certificate when the server's started, instead of in the shellHook.
   overmind = pkgs.writeShellScriptBin "overmind" ''
     carootdir=$(mkcert -CAROOT)
     if [[ ! -f "$carootdir/rootCA.pem" ]]; then
       PATH="${pkgs.nssTools}/bin:$PATH" ${pkgs.mkcert}/bin/mkcert -install
     fi

     extraParams=""
     case "$@" in
       'start')
         ;;
       's')
         extraParams="--root $PROJECT_ROOT"
         ;;
     esac

     OVERMIND_PROCFILE=${procfile} ${pkgs.overmind}/bin/overmind "$@" $extraParams
   '';
in
{
  buildInputs = [ overmind ];
}