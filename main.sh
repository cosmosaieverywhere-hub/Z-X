#!/bin/bash
# 1. Download Paper 1.8.8 if missing
if [ ! -f "paper-1.8.8.jar" ]; then
    echo "Downloading Paper 1.8.8..."
    wget -O paper-1.8.8.jar "https://api.papermc.io/v2/projects/paper/versions/1.8.8/builds/443/downloads/paper-1.8.8-443.jar"
fi

# 2. Start the server
java -Xmx2G -Xms2G -jar paper-1.8.8.jar --port 7860
