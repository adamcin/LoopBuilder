#!/usr/bin/env bash
# https://rderik.com/blog/automating-build-and-testflight-upload-for-simple-ios-apps/#automating-the-build-version-increase
set -eo pipefail
readonly basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly loopdir="$(cd "${basedir}/../Loop" && pwd)"

commit="true"

while [[ "$#" -gt 0 ]]; do
    opt="$1"
    shift
    case "$opt" in
    --no-commit)
    commit="false";;
    *)
    echo "unknown option $opt" >&2
    exit 1;;
    esac
done

pushd "${basedir}"

git -C "${loopdir}" fetch
git -C "${loopdir}" switch -fC adamcin/current remotes/origin/HEAD
cp -f "${basedir}/remove-sim-archs.sh" "${loopdir}/Scripts/remove-sim-archs.sh"
sed -i.bak \
	's/\(rsync .* "\${plugin_as_framework_path}"\)$/\1 \&\& "${SRCROOT}\/Scripts\/remove-sim-archs.sh" "${plugin_as_framework_path}"/' \
	"${loopdir}/Scripts/copy-plugins.sh"

app_version="$(sed -n 's/LOOP_MARKETING_VERSION = //p' "${loopdir}/Loop.xcconfig")"

current_project_version=0
if git config -f versions.gitconfig --get-regexp "loop.v${app_version}.b" >>/dev/null; then
    current_project_version="$(git config -f versions.gitconfig --get-regexp "loop.v${app_version}.b" | cut -f2 -db | cut -f1 -d' ' | sort -rn | head -n 1)"
fi

new_project_version=$((current_project_version + 1))

sed -i.bak \
	-e "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = ${new_project_version};/" \
	-e "s/DEVELOPMENT_TEAM = [^;]*;/DEVELOPMENT_TEAM = X4L3JSUC6J;/" \
	"${loopdir}/Loop.xcodeproj/project.pbxproj"

xcodebuild -allowProvisioningUpdates -allowProvisioningDeviceRegistration -project "${loopdir}/Loop.xcodeproj" -xcconfig "${loopdir}/Loop.xcconfig" -scheme Loop -configuration Release archive -archivePath "$(pwd)/build/Loop.xcarchive"

xcodebuild -allowProvisioningUpdates -allowProvisioningDeviceRegistration -exportArchive -archivePath "$(pwd)/build/Loop.xcarchive" -exportOptionsPlist exportOptions.plist -exportPath "$(pwd)/build"

git config -f versions.gitconfig "loop.v${app_version}.b${new_project_version}" "$(git -C "${loopdir}" rev-parse --short HEAD)"

git add versions.gitconfig

if [[ "$commit" == "true" ]]; then
    git commit -m "uploaded Loop v${app_version} b${new_project_version}"
    git tag "loop.v${app_version}.b${new_project_version}"
    git push --tags
fi
