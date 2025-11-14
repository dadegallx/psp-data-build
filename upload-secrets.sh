#!/bin/bash

set -e

ENV_FILE="${1:-.env}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: $ENV_FILE not found"
  exit 1
fi

echo "Uploading secrets from $ENV_FILE..."
echo ""

while IFS= read -r line; do
  # Skip empty lines and comments
  [[ -z "$line" || "$line" =~ ^# ]] && continue

  # Remove 'export ' prefix if present
  if [[ "$line" =~ ^export[[:space:]]+(.*) ]]; then
    line="${BASH_REMATCH[1]}"
  fi

  # Parse key=value
  key=$(echo "$line" | cut -d= -f1 | xargs)
  value=$(echo "$line" | cut -d= -f2- | xargs)

  # Remove quotes from value
  value=$(echo "$value" | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')

  echo "Setting secret: $key"
  gh secret set "$key" --body "$value"

done < "$ENV_FILE"

echo ""
echo "✅ Done! All secrets uploaded successfully."
echo ""
echo "Verify with: gh secret list"
