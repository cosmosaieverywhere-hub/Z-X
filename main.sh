#!/bin/bash

# Define the port (HF uses 7860)
RUN_PORT=${PORT:-7860}

echo "Starting Z-X Server on port $RUN_PORT..."

# If you have specific config files that need the port changed, 
# you can use 'sed' here to inject the port before starting.
# Example: sed -i "s/25577/$RUN_PORT/g" config.yml

# Start the Java process
java -Xmx2G -jar BungeeCord.jar
