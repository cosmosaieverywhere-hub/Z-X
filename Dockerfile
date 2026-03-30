# 1. Use a stable, supported Java 17 image (Standard for Eaglercraft/1.12.2)
FROM eclipse-temurin:17-jdk-focal

# Install necessary tools for downloading and running
RUN apt-get update && apt-get install -y curl ca-certificates && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /server

# 2. Copy your repo files (This gets your config, run.sh, and plugins)
COPY . .

# 3. MANUALLY DOWNLOAD THE MISSING LFS JAR
# Since the GitHub LFS budget is hit, we download the 1.12.2 server jar directly
RUN mkdir -p cache && \
    curl -L -o cache/mojang_1.12.2.jar https://piston-data.mojang.com/v1/objects/1b557e529340f12959882f0e651db501375d8471/server.jar

# 4. Setup permissions and EULA
RUN chmod +x ./run.sh
RUN echo "eula=true" > eula.txt

# 5. Eaglercraft Ports
# 8081: Default for Eaglercraft WebSocket
# 25565: Internal Minecraft traffic
# 8080: Web server (if applicable)
EXPOSE 8081
EXPOSE 25565
EXPOSE 8080

# Use exec to handle Render's termination signals properly
CMD ["/bin/bash", "./run.sh"]
