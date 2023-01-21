{ pkgs, ... }:

{
  packages = with pkgs;[ 
    kubectl
    kubectx
    stern
  ];

  enterShell = ''
    echo -e "\033[1mKubernetes devenv\033[0m"
    echo "kubectl: $(kubectl version --short --client=true 2> /dev/null)"
    echo "kubectx: $(kubectx --version)"
    echo "sern: $(stern --version)"
  '';
}
