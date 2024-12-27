{ nixpkgs, pulls, ... }:
let
  pkgs = import nixpkgs { };
  prs = builtins.fromJSON (builtins.readFile pulls);
  prJobsets = pkgs.lib.mapAttrs' (num: info: {
    name = "PR${num}";
    value = {
      checkinterval = 600;
      description = "${info.title}";
      emailoverride = "";
      enabled = 1;
      enableemail = false;
      flake = "git+ssh://git@github.com/timhae/aria2_exporter?rev=${info.head.sha}";
      hidden = false;
      keepnr = 1;
      schedulingshares = 20;
      type = 1;
    };
  }) prs;
  mkFlakeJobset = branch: {
    checkinterval = 3600;
    description = "branch ${branch}";
    emailoverride = "";
    enabled = 1;
    enableemail = false;
    flake = "git+ssh://git@github.com/timhae/aria2_exporter?ref=${branch}";
    hidden = false;
    keepnr = 3;
    schedulingshares = 100;
    type = 1;
  };
  desc = prJobsets // {
    "master" = mkFlakeJobset "master";
  };
  log = {
    pulls = prs;
    jobsets = desc;
  };
in
{
  jobsets = pkgs.runCommand "spec-jobsets.json" { } ''
    cat >$out <<EOF
    ${builtins.toJSON desc}
    EOF
    # This is to get nice .jobsets build logs on Hydra
    cat >tmp <<EOF
    ${builtins.toJSON log}
    EOF
    ${pkgs.jq}/bin/jq . tmp
  '';
}
