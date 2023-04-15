#!/bin/sh

# godot-package helper
# @author Erodozer <ero@erodozer.moe>
#
# Simple Bach Script that fetches and merges standard godot addon repositories from github
# to your project.  You can use this instead of Godot's Asset Library if you wish to
# include dependencies in your projects while developing, but not include them in your git.
#
# Run this from the root directory of your project
#
# It parses a json file called godot_packages.json with the following schema
#
# [
#   {
#     "git": "<user>/<repo>",
#     "branch" ?: string, # main is the default
#     "tag" ?: string, # only set this if you want to lock to a specific published version
#   },
#   ...
# ]
# 
# Downloaded addons are merged into your project's addon's folder.
# If the addon as a LICENSE file in the root of the repo, it is copied to the addon's nested folder
# .gitignore files are also added to the nested folder.
#
#
# Requires:
#   unzip
#   jq
#   wget


TMP_DIR=".godot-addon-tmp"

mkdir -p $TMP_DIR

for row in $(jq -c '.[]' godot_packages.json); do
    # parse record
    _jq() {
        echo "${row}" | jq -r "${1}"
    }

    git=$(_jq '.git')
    outfile=$(echo "$git" | tr "/" _)
    user=$(echo "$git" | cut -d "/" -f 1)
    repo=$(echo "$git" | cut -d "/" -f 2)
    branch=$(_jq ".branch // \"main\"" )
    version=$(_jq '.tag')
    
    if [[ -z version ]]; then
        wget -O "$TMP_DIR/$outfile.zip" "https://github.com/$user/$repo/archive/refs/tags/$version.zip"
    else
        wget -O "$TMP_DIR/$outfile.zip" "https://github.com/$user/$repo/archive/refs/heads/$branch.zip"
    fi

    unzip -d $TMP_DIR/$user "$TMP_DIR/$outfile.zip"

    package_folder="$TMP_DIR/$user/$repo-main"
    addons_folder="$package_folder/addons"

    for dir in $(ls -d $addons_folder/*); do
        echo "*" > "$dir/.gitignore"
        cp "$package_folder/LICENSE" "$dir/LICENSE"
    done

    cp -r "$TMP_DIR/$user/$repo-main/addons" "."
done

rm -r $TMP_DIR
