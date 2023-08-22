#!/bin/sh
set -e

f=rt.dump.`date +%Y.%m.%d`
d=/var/psqlbackups
pg_dump -U postgres -T sessions -c -f $d/$f rt4
gzip -9 $d/$f
find $d -name 'rt.dump.*.gz' -mtime +30 -delete

find /var/cache/request-tracker4 -type f -mtime +1 -delete
