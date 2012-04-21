# Script to test krb5 hook scripts.  Run in an empty directory.
# git's default idea of your email address must match the mapping of
# your username in githooks/authors.

datadir=`dirname $0`
wd=`pwd`

# Create test master repository with hooks.
rm -rf central
git init --bare central
cd central
cp $datadir/../githooks/* hooks
cp $datadir/test-cvsgate hooks
git config hooks.mailinglist -
git config hooks.reponame testrepo
git config hooks.rt-ssh-cmd $wd/central/hooks/test-cvsgate
git remote add github-krb5 $wd/mirror
git config remote.github-krb5.mirror true
cd ..

# Create test push target.
rm -rf mirror
git init --bare mirror

# Create test client repository.
rm -rf client
git init client
cd client
git remote add central $wd/central

# Make some commits on master testing post-receive-notify and post-receive-rt.
# (After the first commit, create a branch to be fast-forwarded later.)
(echo 'Test file 1'; echo 'line 2') > file1
git add file1
git commit -m 'One line commit message'
git branch test-ff
echo 'line 3' >> file1
git commit -a -m 'Multi-line commit message

with valid summary and no RT headers'
echo 'Test file 2' > file2
git add file2
git commit -m 'Commit message

with a body and then RT headers (but nothing special)
ticket: 1234
target_version: 1.3'
echo 'line 2 for file 2' >> file2
echo 'line 4' >> file1
git commit -a -m 'Another commit message with RT headers

ticket: 1235 (new)
tags: pullup
subject: Subject supplied in RT headers'
git rm file2
git commit -a -m 'Summary line acting as ticket subject

because RT headers imply new ticket but do not contain subject

ticket: 1236 (new)
version_fixed: 1.3'
perl -e 'print "\n" x 5000 . "foo\n"' > bigfile
git add bigfile
git commit -m 'Big diff suppressed'

# Create a branch at the same rev as master (to test that revs are
# only processed once in a push, even if they're new to several
# branches).
git branch test-duplicate

# Push what we have so far.
echo "****** Push 1"
git push central master test-ff test-duplicate
echo "****** End push 1"

# Fast-forward a branch along master and test that we get a notification
# about the branch head move but not about the existing commits.
echo "****** Push 2"
git update-ref refs/heads/test-ff refs/heads/master
git push central test-ff
echo "****** End push 2"

# Make a branch with more than 50 commits.  This will hopefully never
# happen in practice, but this tests the sanity check in post-receive
# which makes sure we don't spam the list if it erroneously identifies
# a large number of commits.
git checkout -b longbranch
for i in 0 1 2 3 4 5; do for j in 0 1 2 3 4 5 6 7 8 9; do
    echo $i$j > busyfile
    git add busyfile
    git commit -m "Commit $i$j to longbranch"
done; done
echo "****** Push 3"
git push central longbranch
echo "****** End push 3"
git checkout master

# Test notifications for tags.
git tag -a -m 'Annotated tag message' atag
git tag ntag
echo "****** Push 4"
git push central atag ntag
echo "****** End push 4"
