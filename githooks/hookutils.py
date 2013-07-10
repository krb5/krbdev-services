import os
import subprocess
import sys

# The SHA-1 hash used by git to indicate ref creation or deletion.
no_rev = '0' * 40

verbose = True

# Run a command and return a list of its output lines.
def run(args):
    # Can't use subprocess.check_output until 2.7 (drugstore has 2.4).
    p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate()
    if p.returncode != 0:
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

if run(['git', 'config', 'hooks.verbose'])[0].lower() == 'false':
    verbose = False
