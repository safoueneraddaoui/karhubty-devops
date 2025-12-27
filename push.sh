#!/usr/bin/env bash
set -euo pipefail

# push.sh — add, commit (prompt for message if not provided), and push current branch

if ! command -v git >/dev/null 2>&1; then
  echo "git not found in PATH" >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository (or inside a git work tree)." >&2
  exit 1
fi

# Determine current branch robustly (works when HEAD may be unborn)
branch=$(git symbolic-ref --short HEAD 2>/dev/null || git branch --show-current 2>/dev/null || true)
if [ -z "$branch" ]; then
  if branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null); then
    :
  fi
fi
if [ -z "$branch" ]; then
  read -r -p "Could not determine current branch. Enter branch name [main]: " branch
  branch=${branch:-main}
fi

# If arguments provided, use them as the commit message; otherwise prompt the user
if [ "$#" -ge 1 ]; then
  msg="$*"
else
  read -r -p "Commit message: " msg
fi

if [ -z "${msg// /}" ]; then
  echo "Empty commit message — aborting." >&2
  exit 1
fi

git add .

# Try to commit; handle case where there are no staged changes
if git commit -m "$msg"; then
  echo "Committed changes with message: $msg"
else
  echo "Commit failed — there may be no changes to commit." >&2
  exit 1
fi

echo "Fetching updates from origin..."
git fetch origin

# If the remote branch exists, rebase the current branch onto it.
if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
  echo "Rebasing onto origin/$branch (pull --rebase --autostash)..."
  if ! git pull --rebase --autostash origin "$branch"; then
    echo "Rebase/pull failed. Resolve conflicts, then run 'git rebase --continue' or 'git rebase --abort'." >&2
    exit 1
  fi 
else
  echo "Remote branch origin/$branch not found — skipping pull/rebase."
fi

# Push and set upstream if needed
echo "Pushing to origin/$branch..."
if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
  git push origin "$branch"
else
  # If there is no upstream, set it on push
  git push --set-upstream origin "$branch"
fi

echo "Push complete."