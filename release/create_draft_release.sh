#!/bin/bash
set -ex

# This script will be called when a new content was merged to the main branch.
# It will create a new draft release.
export new_tag="$1"

if [ -z "$new_tag" ]
then
      echo "Calculating next tag"
      source release/calculate_next_tag.sh
else
      echo "Using provided tag: $new_tag"
fi

git checkout main
git pull

git tag "$new_tag"
git push origin "$new_tag"

message="Fill release notes here."

gh release create "$new_tag" --draft --title "$new_tag" --notes "- $message"
