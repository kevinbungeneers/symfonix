{ pkgs }:

{
  processes.npm-watch.exec = "npm run watch";
  buildInputs = [ pkgs.nodejs_20 ];
}