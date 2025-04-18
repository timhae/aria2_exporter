{ pkgs, ... }:
let
  port = 9578;
  rpcSecret = "integration-test";
in
{
  name = "integration test";
  nodes = {
    server = {
      imports = [ ./module.nix ];

      environment.etc."aria2Rpc".text = rpcSecret;

      services.aria2_exporter = {
        inherit rpcSecret;
        enable = true;
        listenAddress = ":${toString port}";
      };

      networking.firewall.allowedTCPPorts = [ port ];

      services.aria2 = {
        rpcSecretFile = "/etc/aria2Rpc";
        enable = true;
        openPorts = true;
        settings.rpc-listen-all = true;
      };
    };
    client =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          (writeShellScriptBin "run-test" ''
            set -exuo pipefail
            dd if=/dev/urandom of=test.bin bs=1M count=1
            ${mktorrent}/bin/mktorrent test.bin
            info_hash=$(${aria2}/bin/aria2c -S test.bin.torrent | grep -E 'Info Hash: .*' | grep -oE '[0-9a-f]{40}')
            ${curl}/bin/curl -XPOST http://server:6800/jsonrpc -d '{
              "jsonrpc": "2.0",
              "id": "test",
              "method": "aria2.addTorrent",
              "params": [
                "token:${rpcSecret}",
                "'"$(base64 -w 0 test.bin.torrent)"'"
              ]
            }'
            ${curl}/bin/curl -s http://server:${toString port}/metrics | grep 'aria2_torrent_size_bytes{hash="'"$info_hash"'",torrent="test.bin"} 1.048576e+06'
          '')
        ];
      };
  };

  testScript = ''
    start_all()
    server.wait_for_open_port(${toString port})
    client.wait_for_unit("multi-user.target")

    client.succeed("run-test")
  '';
}
