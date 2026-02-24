#! @bash@/bin/bash
# shellcheck shell=bash

exec @dev@/libexec/g-ir-scanner \
    --use-binary-wrapper=@emulatorwrapper@ \
    --use-ldd-wrapper=@dev@/bin/g-ir-scanner-lddwrapper \
    "$@"
