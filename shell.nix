# Development shell for the yapper Discourse plugin.
#
# Usage:
#   nix-shell
#
# Provides Ruby + Node + pnpm at the versions Discourse 8.x expects, plus
# git. Gems and node modules install under the plugin directory so the
# shell stays self-contained and doesn't pollute the host.
#
# This file lives in the plugin repo so collaborators get a working dev
# environment with one command.

{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "yapper-dev";

  buildInputs = with pkgs; [
    ruby_3_4
    nodejs_22
    nodePackages.pnpm
    git
  ];

  shellHook = ''
    export GEM_HOME="$PWD/.gems"
    export GEM_PATH="$GEM_HOME"
    export PATH="$GEM_HOME/bin:$PWD/node_modules/.bin:$PATH"

    echo "Yapper Development Environment"
    echo "=============================="
    echo "Ruby:  $(ruby --version)"
    echo "Node:  $(node --version)"
    echo "pnpm:  $(pnpm --version)"
    echo ""
    echo "Lint and test usually run from inside the dv container against"
    echo "the parent Discourse repo. This shell is for editing the plugin"
    echo "and running pnpm/bundle commands locally."
    echo ""
    echo "Quick commands:"
    echo "  bundle install                          - install Ruby gems"
    echo "  bundle exec rubocop                     - lint Ruby"
    echo "  bundle exec stree write **/*.rb         - format Ruby"
  '';
}
