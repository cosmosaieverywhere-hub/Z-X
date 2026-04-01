#!/bin/bash
# Use the port HF provides, or default to 7860
RUN_PORT=${PORT:-7860}

echo "Starting server on port $RUN_PORT..."
# Example for BungeeCord/Eaglercraft
# You may need to edit your config.yml to match this port!
java -Xmx2G -jar BungeeCord.jar
