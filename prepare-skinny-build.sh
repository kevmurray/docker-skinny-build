#!/bin/bash

# C

IFS=$'\n'

log() { echo "[$(date +%F_%T)] " "$@" >>/dev/stderr; }
fatal() { log "$@"; exit 1; }

# Given a skinny file, finds the real path for it. If it starts with / then it is a full path,
# but if it doesn't then it is assumed to be relative to the root
normalizeSkinnyFile() {
  local file=$1

  [[ "$file" == /* ]] && { realpath "$file"; return $?; }
  [[ "$file" == ~* ]] && { realpath "$file"; return $?; }
  [ "$rootDir" ] || fatal "cannot resolve file '$file', you must provide a root directory for relative files"
  realpath "$rootDir/$file"
}

# getRoot tries to discover the root of the project
getRoot() {
  # look for a parent in the first skinny directory that contains .git
  local file=$(echo "$skinnyFiles" | head -n1)
  findGitDir $(normalizeSkinnyFile "$file")
}

# Searches path of a directory looking for the closest parent that has a .git file
findGitDir() {
  local p=$1
  [ -f "$p" ] && p=dirname "$p"
  until [ -d "$p/.git" ]; do
    [ "$p" ] || return 1
    [ "$p" == "." ] && return 1
    [ "$p" == "/" ] && return 1
    p=$(dirname "$p")
  done
  echo "$p"
  return 0
}

linkFile() {
  local file=$1

  [[ "$file" == "$rootDir"/* ]] || fatal "file $file is not in $rootDir"
  local partial=${file#$rootDir/}
  mkdir -p "$tmpRoot/$(dirname "$partial")"
  [ "$tmpRoot/$partial" ] && rm -f "$tmpRoot/$partial"
  ln -s "$file" "$tmpRoot/$partial"
}


verbose=false

# try to get a default root path from the current directory
rootDir=$(findGitDir $(realpath $(pwd)))
skinnyFiles=
while [ "$1" ]; do
  case "$1" in
    --verbose|-v)
      verbose=true
      ;;
    --root)
      rootDir=$(realpath $2)
      shift
      ;;
    --root=*)
      rootDir=$(realpath ${1#*=})
      ;;
    *)
      skinnyFiles="$skinnyFiles"$'\n'"$1"
      ;;
  esac
  shift
done
skinnyFiles=$(echo "$skinnyFiles" | grep -v "^$")
[ "$skinnyFiles" ] || fatal "cannot find any files or directories to build with"


{
  # prepare the temporary root directory
  [ "$rootDir" ] || {
    rootDir=$(getRoot) || fatal "cannot find a root directory for this project, provide a --root argument"
    $verbose && log "Found root directory $rootDir"
  }
  tmpRoot=/tmp/$(basename "$rootDir")
  rm -r "$tmpRoot"
  mkdir -p "$tmpRoot" || fatal "cannot create temporary directory $tmpRoot"

  # copy all the root files to the tmp directory
  for rootFile in $(ls -1A "$rootDir"); do
    [ -d "$rootDir/$rootFile" ] && continue
    $verbose && log "Root file: $rootFile"
    cp "$rootDir/$rootFile" "$tmpRoot"
  done

  # create symlinks for all the skinny files in the tmp directory
  for skinnyFile in $skinnyFiles; do
    $verbose && log "Skinny file: $skinnyFile"
    linkFile $(normalizeSkinnyFile "$skinnyFile")
  done

  # output the directory that we prepared
  echo "$tmpRoot"
}
