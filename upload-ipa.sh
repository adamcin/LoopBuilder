#!/usr/bin/env bash
# https://rderik.com/blog/automating-build-and-testflight-upload-for-simple-ios-apps/#automating-the-build-version-increase
set -eo pipefail
readonly basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly loopdir="$(cd "${basedir}/../LoopWorkspace/Loop" && pwd)"

commit="true"
branch="remotes/origin/HEAD"

while [[ "$#" -gt 0 ]]; do
    opt="$1"
    shift
    case "$opt" in
    -b|--branch)
    branch="$1"
    shift;;
    --no-commit)
    commit="false";;
    *)
    echo "unknown option $opt" >&2
    exit 1;;
    esac
done

pushd "${basedir}"

#git -C "${loopdir}" fetch
#git -C "${loopdir}" switch -fC adamcin/current "${branch}"
#git -C "${loopdir}" clean -fdx
#cp -f "${basedir}/remove-sim-archs.sh" "${loopdir}/Scripts/remove-sim-archs.sh"
#sed -i.bak \
#	's/\(rsync .* "\${plugin_as_framework_path}"\)$/\1 \&\& "${SRCROOT}\/Scripts\/remove-sim-archs.sh" "${plugin_as_framework_path}"/' \
#	"${loopdir}/Scripts/copy-plugins.sh"

app_version="$(sed -n 's/LOOP_MARKETING_VERSION = //p' "${loopdir}/Version.xcconfig")"

current_project_version=0
if git config -f versions.gitconfig --get-regexp "loop.v${app_version}.b" >>/dev/null; then
    current_project_version="$(git config -f versions.gitconfig --get-regexp "loop.v${app_version}.b" | cut -f2 -db | cut -f1 -d' ' | sort -rn | head -n 1)"
fi

new_project_version=$((current_project_version + 1))

echo "CURRENT_PROJECT_VERSION = ${new_project_version}" > "${loopdir}/VersionOverride.xcconfig"

xcodebuild -allowProvisioningUpdates -allowProvisioningDeviceRegistration -workspace "${loopdir}/../LoopWorkspace.xcworkspace" -xcconfig "${loopdir}/../LoopConfigOverride.xcconfig" -scheme 'LoopWorkspace' -configuration Release archive -archivePath "$(pwd)/build/Loop.xcarchive" -destination 'generic/platform=iOS'

xcodebuild -allowProvisioningUpdates -allowProvisioningDeviceRegistration -exportArchive -archivePath "$(pwd)/build/Loop.xcarchive" -exportOptionsPlist exportOptions.plist -exportPath "$(pwd)/build"

git config -f versions.gitconfig "loop.v${app_version}.b${new_project_version}" "$(git -C "${loopdir}" rev-parse --short HEAD)"

git add versions.gitconfig

if [[ "$commit" == "true" ]]; then
    git commit -m "uploaded Loop v${app_version} b${new_project_version}"
    git tag "loop.v${app_version}.b${new_project_version}"
    git push --tags
fi
