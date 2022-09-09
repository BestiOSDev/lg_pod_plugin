#!/bin/sh
export LANG=en_US.UTF-8
gem uninstall lg_pod_plugin
gem build
gem install *.gem
