#!/bin/bash
set -ex

# This script will be called when a new content was merged to the main branch.
# It will create a new draft release with the new weka version.

export new_weka_version="$1"

git checkout main
git pull
git fetch --tags
latest_tag=$(git describe --tags "$(git rev-list --tags --max-count=1)")
echo "latest tag: $latest_tag"
major=$(echo "$latest_tag" | cut -d. -f1)
major="${major:1}" # remove v
minor=$(echo "$latest_tag" | cut -d. -f2)
patch=$(echo "$latest_tag" | cut -d. -f3)
new_patch=$((patch + 1))

new_tag="v$major.$minor.$new_patch"
echo "new tag: $new_tag"
git tag "$new_tag"
git push origin "$new_tag"

if [ -z "$new_weka_version" ]
then
      message="Fill release notes here."
else
      message="Updated WEKA default version to $new_weka_version"
fi

gh release create "$new_tag" --draft --title "$new_tag" --notes "- $message"
