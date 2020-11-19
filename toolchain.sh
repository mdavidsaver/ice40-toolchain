#!/bin/bash
set -e

PREFIX=/usr/local
MAKEARGS=
CMD=
while [ $# -gt 0 ]
do
    case "$1" in
    -p|--prefix) PREFIX="$2"; shift 2;;
    -j*) MAKEARGS="$MAKEARGS $1"; shift;;
    build|clean|check-rev|maybe-build) CMD="$1"; shift;;
    *) echo "Usage: $0 [-p <prefix] <build|clean>"
       exit 1
       ;;
    esac
done

HEAD=`git rev-parse HEAD`

case "$CMD" in
build)
    [ -f iverilog/configure ] || (cd iverilog && sh autoconf.sh)
    [ -f iverilog/Makefile ] || (cd iverilog && ./configure --prefix="$PREFIX")

    make $MAKEARGS -C iverilog install

    [ -f yosys/Makefile.conf ] || make -C yosys config-gcc PREFIX="$PREFIX"
    make $MAKEARGS -C yosys PREFIX="$PREFIX"
    make -C yosys PREFIX="$PREFIX" install

    make $MAKEARGS -C icestorm PREFIX="$PREFIX"
    make -C icestorm PREFIX="$PREFIX" install

    [ -f nextpnr/Makefile ] || (cd nextpnr && cmake . -DARCH=ice40 -DICESTORM_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_PREFIX="$PREFIX")
    make $MAKEARGS -C nextpnr install

    install -d "$PREFIX/share/toolchain"
    echo "$HEAD" > "$PREFIX/share/toolchain/revision"

    ;;
clean)
    git submodule git clean -xdf
    ;;
check-rev)
    if [ -r "$PREFIX/share/toolchain/revision" ]
    then
        BUILT="$(cat "$PREFIX/share/toolchain/revision")"
        echo "Current: $HEAD"
        echo "Built  : $BUILT"
        [ "$HEAD" = "$BUILT" ] && exit 0
    fi
    exit 1
    ;;
maybe-build)
    "$0" -p "$PREFIX" check-rev || "$0" -p "$PREFIX" build
    ;;
*) echo "Usage: $0 [-p <prefix] <build|clean>"
    exit 1
    ;;
esac
