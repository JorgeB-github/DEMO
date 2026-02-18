#!/bin/bash

# Checkout SIT branch
git checkout release-1

# Pull latest changes from SIT branch
git pull origin release-1

# Get current date and time in the required format
DATETIME=$(date "+%d-%m-%H-%M")

# Create and checkout new branch with the specified naming convention (change r1.4.3 when change the release version)
git checkout -b $DATETIME

echo "Created and checked out branch: $DATETIME"

# Wait 5 seconds
echo "Waiting..."
sleep 5
