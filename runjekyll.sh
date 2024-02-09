#!/bin/bash
source "/usr/local/rvm/bin/rvm" # or equivalent for rbenv or asdf
cd "${workspaceFolder}" # Adjust path as necessary
bundle exec jekyll serve