#!/bin/bash

# YT Agent Deployment Script
# Usage: ./deploy.sh

set -e  # Exit on error

echo "Starting deployment..."

# Pull latest code from main branch
echo "Pulling latest code from main branch..."
git pull origin main

# Install/update dependencies
echo "Installing dependencies..."
bundle install

# Run database migrations
echo "Running database migrations..."
RAILS_ENV=production bin/rails db:migrate

sudo systemctl restart puma-yt-agent
echo "Restarted Puma"
