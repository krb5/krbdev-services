import os
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

_verbose = config_get('hooks.verbose', default='true')
if _verbose.lower() in ('false', 'no', 'n'):
    verbose = False
