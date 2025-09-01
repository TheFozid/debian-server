#!/bin/bash

# How to use -> ./ollama-model-downloads.sh gemma3:4b-it-q8_0 /path/to/download

# Ensure correct usage
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <name:tag> <download_path>"
    exit 1
fi

# Split the first input at ":" into name and tag
IFS=":" read -r VARIABLE1 VARIABLE2 <<< "$1"

# Check if both parts exist
if [ -z "$VARIABLE1" ] || [ -z "$VARIABLE2" ]; then
    echo "Error: Input must be in the format name:tag (e.g., llama2:latest)"
    exit 1
fi

DOWNLOAD_PATH=$2

# Construct URL1
URL1="https://registry.ollama.ai/v2/library/${VARIABLE1}/manifests/${VARIABLE2}"

# Get JSON and extract the SHA256 where mediaType is the model
SHA256_DIGEST=$(curl -s "$URL1" | jq -r '.layers[] | select(.mediaType=="application/vnd.ollama.image.model") | .digest')

# Check if we got the SHA256
if [ -z "$SHA256_DIGEST" ]; then
    echo "Model SHA256 digest not found in manifest."
    exit 1
fi

# Construct URL2
URL2="https://registry.ollama.ai/v2/library/${VARIABLE1}/blobs/${SHA256_DIGEST}"

# Make sure the download path exists
mkdir -p "$DOWNLOAD_PATH"

# Download using wget
wget -O "${DOWNLOAD_PATH}/${VARIABLE1}_${VARIABLE2}.gguf" "$URL2"
