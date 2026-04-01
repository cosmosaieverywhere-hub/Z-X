#!/bin/bash

# 1. Hugging Face needs port 7860
export PORT=7860

# 2. Automatically agree to EULA so the server doesn't hang
echo "eula=true" > eula.txt

# 3. Start the server (It will create the 'world' folder automatically)
# We use -Xmx2G because Hugging Face free tier has about 2-16GB RAM
java -Xmx2G -jar paper-1.12.2.jar --port 7860
