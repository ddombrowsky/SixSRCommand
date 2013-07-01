#!/bin/sh
set -x
/var/lib/gems/1.8/bin/mongrel_rails start -p 3030 -a 192.168.1.2
