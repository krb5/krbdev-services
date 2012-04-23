# Shell script to convert MIT krb5 repository from svn to git.  Run in
# an empty directory with about 1GB of space available.  The output is
# a bare repository in krb5.git (70MB).  Intermediate directories
# krb5-svn (750MB) and krb5-gitsvn (150MB) will also be left behind.

# Requires AFS to get at the krb5 repository mirror.  Requires Python
# 2.7 for edit-logs.py.  Requires svnlook, svnadmin, and git in the
# path.  Requires gnu cp for the -a option.

set -e

datadir=`dirname $0`
if [ ! -r "$datadir/authors" ]; then
    echo "Can't find authors file; run using absolute path" 1>&2
    exit 1
fi

wd=`pwd`
mirror=/afs/athena.mit.edu/astaff/project/krbdev/svn/krb5
svncopy=$wd/krb5-svn
gitsvn=$wd/krb5-gitsvn
bare=$wd/krb5.git

echo "Copying krb5 repository mirror to $svncopy"
cp -a "$mirror" "$svncopy"

echo "Editing log messages in $svncopy"
python "$datadir/edit-logs.py" "$svncopy"

echo "Initializing $gitsvn"
git svn init \
    --trunk=trunk \
    --tags=tags \
    --branches=branches \
    --branches=users/amb \
    --branches=users/coffman \
    --branches=users/hartmans \
    --branches=users/lhoward \
    --rewrite-root=svn://anonsvn.mit.edu/krb5 \
    "file://$svncopy" "$gitsvn" > /dev/null
# Give user branches a username prefix.
gitconf=$gitsvn/.git/config
sed -e 's|users/\([a-z]*\)/\*:refs/remotes|\0/\1|' "$gitconf" > "$gitconf.new"
mv "$gitconf.new" "$gitconf"

# We would like to include users/raeburn/branches in the above, but
# the "syms" and "plugin" branches here are copied from trunk/src,
# which causes git-svn to re-fetch the entire history of src and put
# it onto the branch.  If we find a workaround for that, we would also
# need to (1) modify the sed command above to map
# users/raeburn/branches to refs/remotes/raeburn, and (2) evaluate
# which resulting branches should go into unwanted-branches.

echo "Fetching svn revisions into $gitsvn (output in git-svn-fetch.log)"
(cd "$gitsvn" && git svn fetch "--authors-file=$datadir/authors") \
    > git-svn-fetch.log 2>&1

echo "Creating $bare"
git init -q --bare "$bare"

echo "Pushing from $gitsvn to $bare"
(cd "$gitsvn" && git push -q "$bare" 'refs/remotes/*:refs/heads/*')

# Everything from here on is manipulation of the bare repository.
cd "$bare"

echo "Adjusting branches and tags"

# We had an old branch named HEAD in the svn repository; remove it and
# make a symbolic ref to the trunk branch.
git update-ref -d refs/heads/HEAD
git symbolic-ref HEAD refs/heads/trunk

# Remove unwanted branches.
git branch -D `cat "$datadir/unwanted-branches"` > /dev/null

# Rename branches (and tags, which are currently branches named tags/*).
while read src dest; do
    git branch -m "$src" "$dest"
done < "$datadir/branch-renames"

# Convert tags/* branches to tags.
git for-each-ref --format='%(refname)' refs/heads/tags | cut -d / -f 4 | \
    while read ref; do
        git tag "$ref" "refs/heads/tags/$ref";
        git branch -D "tags/$ref";
    done > /dev/null

# Remove unwanted tags.
git tag -d `cat "$datadir/unwanted-tags"` > /dev/null

# The amb/referrals branch, and the referrals branch derived from it,
# placed a copy of trunk in a subdirectory.  Fix that, and also fix
# the ancestry of the base commit (git-svn chooses two parents, one
# the empty r18406 and the other r18199 because of some svk metadata).
echo "Filtering referrals branches"
refbase=`git rev-parse referrals~72`
git filter-branch --tree-filter 'mv trunk/* . && rmdir trunk' \
    --parent-filter 'test $GIT_COMMIT = '$refbase' &&
        echo "-p :/trunk@18404" || cat' -- \
    --first-parent referrals amb/referrals --not referrals~73 > /dev/null
git update-ref -d refs/original/refs/heads/amb/referrals
git update-ref -d refs/original/refs/heads/referrals

echo "Packing repository"
git gc --quiet --aggressive --prune=now

echo "Configuring repository"
# Configure github-krb5 remote.
echo "Master krb5 git repository" > description
git remote add github-krb5 git@github.com:krb5/krb5.git

# Configure variables used by hook scripts.
git config remote.github-krb5.mirror true
git config hooks.mailinglist cvs-krb5@mit.edu
git config hooks.reponame krb5
git config hooks.rt-ssh-cmd "/git/krb5.git/hooks/ssh-as-krbsnap rtcvs@krbdev-r1.mit.edu /var/rt2/bin/rt-cvsgate"

# Configure variables controlling git-receive-pack behavior.
git config receive.fsckObjects true
git config receive.denyNonFastForwards true
git config core.logAllRefUpdates true
git config gc.reflogexpire never
git config gc.reflogexpireunreachable never

git config core.sharedRepository group

# Install hook scripts.
rm hooks/*
cp $datadir/../githooks/* hooks
