#!/bin/bash
set -ex

export new_tag="$1"
export base_branch="$2"

if [ -z "$new_tag" ]
then
      echo "Calculating next tag"
      source release/calculate_next_tag.sh
fi

if [ -z "$base_branch" ]
then
      base_branch="dev"
fi

git checkout "$base_branch"
git pull
git checkout -b "$base_branch-$new_tag"

if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' 's/= "dev"/= "release"/' variables.tf
else
  sed -i 's/= "dev"/= "release"/' variables.tf
fi
git add variables.tf
git commit -m "chore: update function app distribution to release" || true

git push --set-upstream origin "$base_branch-$new_tag"
capitalized_base_branch=$(echo "$base_branch" | awk '{print toupper(substr($0, 1, 1)) tolower(substr($0, 2))}')
gh pr create --base main --title "$capitalized_base_branch $new_tag" --body ""
gh pr view --web
