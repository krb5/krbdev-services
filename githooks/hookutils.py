import os
import re
import subprocess
import sys

# The SHA-1 hash used by git to indicate ref creation or deletion.
no_rev = '0' * 40

verbose = True

# Run a command and return a list of its output lines.
def run(args, ignorefail=False):
    # Can't use subprocess.check_output until 2.7 (drugstore has 2.4).
    p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate()
    if not ignorefail and p.returncode != 0:
        if verbose:
            sys.stderr.write('Failed command: ' + ' '.join(args) + '\n')
            if err != '':
                sys.stderr.write('stderr:\n' + err)
        sys.stderr.write('Unexpected command failure, exiting\n')
        sys.exit(1)
    return out.splitlines()


# Return the path to a file in the hook directory.
def hookdir_file(name):
    return os.path.join(os.getenv('GIT_DIR'), 'hooks', name)

def config_get(key, default=None):
    if default is None:
        ignorefail = False
    else:
        ignorefail = True
    r = run(['git', 'config', key], ignorefail=ignorefail)
    if not r:
        return default

def config_get_all(key):
    return run(['git', 'config', '--get-all', key], ignorefail=True)

# Regex for cherry pick annotations
_cherry_re = re.compile(r'^\((?:cherry[- ]?picked|back[- ]?ported) '
                       r'from commit [0-9a-f]{40}\)$')
# Regex for trailing comments
_comment_re = re.compile(r'^((\s*)|(#.*))?$')

_empty_re = re.compile(r'^\s*$')

# RT headers
_rtheader_re = re.compile(r'^(RT-)?([\w_-]+):\s*(.*)', re.IGNORECASE)

# Separated by blank lines:
#
# body, meta (cherry-pick and other annotations),
# RT "headers" (really trailers)
class _Commitmsg(object):
    def __init__(self, msg_in):
        msg = list(msg_in)
        comments = []
        while msg and _comment_re.match(msg[-1]):
            comments.insert(0, msg.pop())

        # Trim trailing and leading empty lines from comments
        while comments and _empty_re.match(comments[-1]):
            del comments[-1]
        while comments and _empty_re.match(comments[0]):
            del comments[0]

        cherry = []
        while msg and _cherry_re.match(msg[-1]):
            cherry.insert(0, msg.pop())
        while msg and _empty_re.match(msg[-1]):
            del msg[-1]

        rtheaders = []
        while msg and _rtheader_re.match(msg[-1]):
            rtheaders.insert(0, msg.pop())

        body = []
        for line in msg[::-1]:
            if _cherry_re.match(line):
                cherry.insert(0, line)
            else:
                body.insert(0, line)

        # Trim trailing empty lines from body
        while body and _empty_re.match(body[-1]):
            del body[-1]

        self.body = body
        self.comments = comments
        self.rtheaders = rtheaders
        self.cherry = cherry

    def normalized(self):
        """Normalized list of commit message lines"""
        lines = list(self.body)
        if self.cherry:
            lines += [''] + self.cherry
        if self.rtheaders:
            lines += [''] + self.rtheaders
        if self.comments:
            lines += [''] + self.comments
        return lines


# The tedious I/O bits are here in the public class
class Commitmsg(_Commitmsg):
    def __init__(self, msg_in, f=None):
        if f is not None:
            self.f = f
        return super(Commitmsg, self).__init__(msg_in)

    @classmethod
    def fromcommit(cls, rev):
        msg = run(['git', 'show', '-s', '--format=%B', rev])
        return cls(msg)

    @classmethod
    def _fromfile(cls, f):
        """"Read commit message from an open file"""
        lines = f.read().splitlines()
        return cls(lines, f=f)

    @classmethod
    def _fromfilename(cls, fn):
        """"Read commit message from a named file"""
        f = open(fn, 'r+')
        r = cls._fromfile(f)
        return r

    @classmethod
    def fromfile(cls, f):
        """Read commit message from a file

        This can be an open file object or a filename.
        """
        if isinstance(f, file):
            return cls._fromfile(f)
        else:
            return cls._fromfilename(f)

    def _tofile(self, f=None):
        """Write normalized commit message to an open file

        This replaces the current file contents.
        """
        if f is None:
            f = self.f
        f.seek(0)
        f.truncate()
        s = '\n'.join(self.normalized()) + '\n'
        f.write(s)

    def _tofilename(self, fn):
        """Write normalized commit message to named file"""
        f = open(fn, 'w')
        r = self.tofile(f)
        f.close()
        return r

    def tofile(self, f=None):
        """Write normalized commit message to file

        This replaces the current file contents.  f can be a file
        handle or a filename.  If f is omitted or None, use the open
        file currently associated with this object.
        """
        if f is None or isinstance(f, file):
            return self._tofile(f)
        else:
            return self._tofilename(f)


_verbose = config_get('hooks.verbose', default='true')
if _verbose.lower() in ('false', 'no', 'n'):
    verbose = False
