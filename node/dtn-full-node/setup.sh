#!/bin/bash

# DTN Full Node Setup Script
# This script sets up the complete DTN node with dtn-network and dtn-ai sidecars

set -e

echo "🚀 DTN Full Node Setup"
echo "======================"

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed"
    exit 1
fi

# Check if required files exist
if [ ! -f "full_config.yaml" ]; then
    echo "❌ full_config.yaml not found"
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️  .env file not found"
    echo "📝 Creating .env file from template..."
    if [ -f "env.example" ]; then
        cp env.example .env
        echo "✅ Created .env file from template"
        echo "📝 Please edit .env file with your actual values before running docker-compose"
    else
        echo "❌ env.example not found"
        exit 1
    fi
fi

# Install Python dependencies if needed
echo "📦 Checking Python dependencies..."
python3 -c "import yaml" 2>/dev/null || {
    echo "📦 Installing PyYAML..."
    pip3 install PyYAML
}

# Generate docker-compose with sidecars
echo "🐳 Generating docker-compose configuration..."
python3 generate-compose.py

# Make scripts executable
chmod +x generate-compose.py

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Edit .env file with your actual values"
echo "2. Run: docker-compose up -d"
echo "3. Check logs: docker-compose logs -f"
echo ""
echo "📁 Generated files:"
echo "  - docker-compose.yml (complete setup)"
echo ""
echo "🔍 To view service status:"
echo "  docker-compose ps"
echo ""
echo "🛑 To stop services:"
echo "  docker-compose down" 