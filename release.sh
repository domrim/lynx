#!/usr/bin/env bash
set -x

docker_exec="docker run --rm -it -v ./:/lynx -w /lynx docker.io/library/node:22 /bin/bash -c"

# get current branch
branch=$(git symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')

# push any local changes
git push

# run a build to catch any uncommitted updates
$docker_exec "npm run build"

# branch validation
if [ $branch = "dev" ]; then
	# check current branch is clean
	if output=$(git status --porcelain) && [ -z "$output" ]; then
		
		# get the version number
		echo "Enter the release version (eg. 1.2.0):"
		read version

		echo "Started releasing Lynx v$version..."

		# update package version
		jq --arg version "$version" '.version=$version' package.json > package.tmp && mv package.tmp package.json
		sed -i "" -e "1s/^\(\/\*! Lynx \)v[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}/\1v$version/" assets/css/main.css

		# update changelog
		chan release $version || exit
        $docker_exec "npx prettier --write CHANGELOG.md"

		# build project
        $docker_exec "npm run build"

		# commit version updates
		git commit -a -m "🔨 Preparing release v$version"
		git push

		# switch to stable branch
		git checkout stable

		# pull latest from stable
		git pull

		# merge in changes from dev branch
		git merge --no-ff dev -m "🔖 Release v$version"

		# create tag
		git tag "v$version"

		# push commit and tag to remote
		git push
		git push --tags

		# publish GitHub release
		timeout 2 chan gh-release $version

		echo "Lynx v$version successfully released! 🎉"
		echo "Returning to dev branch..."

		git checkout dev

	else	
		echo "ERROR: There are unstaged changes in development!"
		echo "Clean the working directory and try again."
	fi
else 
	echo "ERROR: Releases can only be published from the dev branch!"
fi
