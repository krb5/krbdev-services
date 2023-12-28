#!/bin/sh

# This script produces a modified Windows installation image named
# kfwdev.iso, containing setup materials for a Kerberos for Windows
# development environment.

if [ $# != 1 ]; then
    echo "Usage: $0 isofile"
    exit 1
fi
isofile=$1
if [ ! -r "$isofile" ]; then
    echo "Cannot read ISO file $1"
    exit 1
fi

if ! command -v 7z > /dev/null; then
    echo "This script requires 7z (sudo apt install p7zip-full)"
    exit 1
fi
if ! command -v xorrisofs > /dev/null; then
    echo "This script requires xorrisofs (sudo apt install xorriso)"
    exit 1
fi

srcdir=`dirname $0`
if [ ! -r "$srcdir/autounattend.xml" -o ! -r "$srcdir/kfwsetup.ps1" ]; then
    echo "Cannot find required files in $srcdir"
    exit 1
fi

rm -rf workdir
mkdir workdir
7z -oworkdir/tree x "$isofile"
mkdir -p 'workdir/additions/sources/$OEM$/$$/Setup/Scripts'
cp "$srcdir/autounattend.xml" workdir/additions
cp "$srcdir/kfwsetup.ps1" 'workdir/additions/sources/$OEM$/$$/Setup/Scripts'

xorrisofs -iso-level 4 -r -U -no-emul-boot -boot-load-size 8 -eltorito-alt-boot -eltorito-platform efi -b efi/microsoft/boot/efisys_noprompt.bin -o kfwdev.iso workdir/tree workdir/additions

rm -rf workdir
