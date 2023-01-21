{ pkgs, ... }:

{
  packages = with pkgs;[
    jq
    gawk
  ];

  enterShell = ''
    echo -e "\033[1mScripting\033[0m"
    echo "awk: $(awk --version | head -n 1)"
    echo "jq: $(jq --version)"
  '';
}
