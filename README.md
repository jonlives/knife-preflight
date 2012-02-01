# knife-preflight

A preflight plugin for Chef::Knife which lets you see which nodes and roles use a particular cookbook before you upload it.

# Installation

## SCRIPT INSTALL

Copy preflight.rb script from lib/chef/knife to your ~/.chef/plugins/knife directory.

## GEM INSTALL
knife-prelight is available on rubygems.org - if you have that source in your gemrc, you can simply use:

````
gem install knife-preflight
````

## Preface

Searches the expanded run_lists of all nodes along with the run_list of all roles for the specified cookbook

## What it does

knife preflight apache2::default
will return a list of all nodes containing this cookbook in their expanded run_list followed by all nodes with the cookbook in their expanded run_list

## Notes
This will currently only search for cookbooks. It won't work if you specify a role on the command line because I've tried to avoid duplication of functionality which knife makes obvious. 

