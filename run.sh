#!/bin/bash

# Chinese Checker - Docker Run Script
# This script builds and runs the Chinese Checker application in Docker

set -e

echo "🐳 Chinese Checker - Docker Runner"
echo "=================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed"
    echo "Please install Docker from https://www.docker.com/get-started"
    exit 1
fi

# Check if docker-compose is available
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo "❌ Error: docker-compose is not available"
    echo "Please install docker-compose or use Docker Desktop"
    exit 1
fi

# Create directories if they don't exist
echo "📁 Ensuring directories exist..."
mkdir -p input known unknown

# Check if input directory has files
if [ -z "$(ls -A input/*.txt 2>/dev/null)" ]; then
    echo "⚠️  Warning: No .txt files found in input/ directory"
    echo "   Please add Chinese text files to analyze"
fi

# Build and run with docker-compose
echo ""
echo "🔨 Building Docker image..."
$COMPOSE_CMD build

echo ""
echo "🚀 Running Chinese Checker..."
echo "=================================="
echo ""
$COMPOSE_CMD up

echo ""
echo "✅ Done!"