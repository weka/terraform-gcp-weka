#!/bin/bash
set -ex

# By default, new terraform releases will be aligned with new weka version releases.
# This script will be used for this release flow, i.e. when a new weka release is published.
# For terraform module hot fixes we will have a different release flow.
# prerequisites: github cli: https://cli.github.com/

export new_weka_version="$1"
export base_branch="$2"

if [ -z "$new_weka_version" ]
then
      echo "Please provide the new weka version"
      exit 1
fi

if [ -z "$base_branch" ]
then
      base_branch="dev"
fi

git checkout "$base_branch"
git pull
git checkout -b "$base_branch-$new_weka_version"
old_weka_version=$(awk '/WEKA version/{getline;print $NF;}' variables.tf | tr -d \")

file_paths=(
    variables.tf
    examples/private_vpc_create_worker_pool/main.tf
    examples/private_vpc_with_peering/main.tf
)
for file_path in "${file_paths[@]}"; do
    if [[ "$OSTYPE" == "darwin"* ]]; then
    	sed -i '' "s/$old_weka_version/$new_weka_version/" "$file_path"
    else
    	sed -i "s/$old_weka_version/$new_weka_version/" "$file_path"
    fi
    git add "$file_path"
done

git commit -m "chore: update weka default version: $new_weka_version"
git push --set-upstream origin "$base_branch-$new_weka_version"
capitalized_base_branch=$(echo "$base_branch" | awk '{print toupper(substr($0, 1, 1)) tolower(substr($0, 2))}')
gh pr create --base main --title "$capitalized_base_branch $new_weka_version" --body ""
gh pr view --web
