#!/bin/bash
set -ex

# By default, new terraform releases will be aligned with new weka version releases.
# This script will be used for this release flow, i.e. when a new weka release is published.
# For terraform module hot fixes we will have a different release flow.
# prerequisites: github cli: https://cli.github.com/

export new_weka_version="$1"
if [ -z "$new_weka_version" ]
then
      echo "Please provide the new weka version"
      exit 1
fi

git checkout dev
git pull
git checkout -b "dev-$new_weka_version"
old_weka_version=$(awk '/Weka version/{getline;print $NF;}' variables.tf | tr -d \")

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
git push --set-upstream origin "dev-$new_weka_version"
gh pr create --base main --title "Dev $new_weka_version" --body ""
gh pr view --web
