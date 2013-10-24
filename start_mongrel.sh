#!/bin/sh
set -x

# mongrel is busted, grrrr...
#/var/lib/gems/1.8/bin/mongrel_rails start -p 3030 -a 192.168.1.2

./script/server -b 192.168.1.2 -p 3030
