#!/bin/sh
set -e
kinit -k -t /var/lib/buildbot/krbsnap.keytab krbsnap@ATHENA.MIT.EDU
aklog athena.mit.edu
trunksnap=/afs/athena.mit.edu/astaff/project/kerberos/krb5-current/krb5-current
buildmaster=/var/lib/buildbot/master
(cd $trunksnap && tar zxof $buildmaster/rst_html.tgz)
kdestroy
unlog
