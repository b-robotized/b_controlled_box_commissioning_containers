#!/bin/bash
set -e

# Start chrony NTP service as root in the background
echo "Starting chrony NTP server..."
sudo chronyd

# Execute the main container command (what's in CMD)
exec "$@"