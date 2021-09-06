#!/bin/sh -e
shopt -s nullglob
function removeSimArchitectures {

    FRAMEWORK="$1"
    echo "Check for sim architectures to remove in framework: $FRAMEWORK"

    FRAMEWORK_EXECUTABLE_NAME=$(defaults read "$FRAMEWORK/Info.plist" CFBundleExecutable)
    FRAMEWORK_EXECUTABLE_PATH="$FRAMEWORK/$FRAMEWORK_EXECUTABLE_NAME"

    if [ ! -f "${FRAMEWORK_EXECUTABLE_PATH}" ]; then
        return
    fi

    if xcrun lipo -info "${FRAMEWORK_EXECUTABLE_PATH}" | grep --silent "Non-fat"; then
        echo "   $FRAMEWORK_EXECUTABLE_NAME non-fat, skipping"
        return
    fi

    ARCHS=$(lipo -archs "$FRAMEWORK_EXECUTABLE_PATH")

    for ARCH in $ARCHS
    do
        if [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "i386" ]; then
        echo "   Removing $ARCH from $FRAMEWORK_EXECUTABLE_NAME"
        xcrun lipo -remove "$ARCH" "$FRAMEWORK_EXECUTABLE_PATH" -o "$FRAMEWORK_EXECUTABLE_PATH"
        fi
    done
}

removeSimArchitectures "$@"
