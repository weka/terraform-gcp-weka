#!/bin/bash

set -ex

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
git checkout -
