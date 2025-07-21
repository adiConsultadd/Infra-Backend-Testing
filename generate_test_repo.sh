#!/bin/bash

# This script creates the standard directory structure for Lambda Layers.

echo "Creating layer directories: common, google, openai..."

# The '-p' flag tells mkdir to create parent directories as needed
# and prevents errors if the directories already exist.
mkdir -p layers/common
mkdir -p layers/google
mkdir -p layers/openai

echo "Creating requirements.txt files..."

# Use 'echo' with redirection '>' to create each file with placeholder content.
echo "# Add common dependencies like redis, psycopg2-binary here." > layers/common/requirements.txt
echo "# Add Google-specific dependencies like langchain-google-genai here." > layers/google/requirements.txt
echo "# Add OpenAI-specific dependencies like openai, langchain-community here." > layers/openai/requirements.txt

echo "✅ Layer structure created successfully!"
