# rely on github-cli

gh repo list myorgname --limit 4000 | while read -r repo _; do
  gh repo clone "$repo" "$repo"
done
