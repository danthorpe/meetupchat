#!/usr/bin/env bash
source /usr/local/opt/chruby/share/chruby/chruby.sh
chruby 2.1.2
rake xcode:distribute:beta