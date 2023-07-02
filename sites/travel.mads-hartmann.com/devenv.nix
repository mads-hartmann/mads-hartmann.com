{ pkgs, ... }:

{
  packages = [
    pkgs.simple-http-server
  ];

  processes = {
    serve.exec = "simple-http-server -p 8000 --ip 0.0.0.0 --index src";
  };

}
