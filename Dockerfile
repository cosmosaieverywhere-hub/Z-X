FROM eclipse-temurin:17-jre-focal

# 1. Install necessary Linux tools
RUN apt-get update && apt-get install -y bash curl wget git python3 && rm -rf /var/lib/apt/lists/*

# 2. Setup Hugging Face User (User 1000 is required)
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user
WORKDIR $HOME/app

# 3. Copy all files from GitHub into the container
COPY --chown=user:user . .

# 4. Make scripts executable
RUN chmod +x main.sh

# 5. Open the Hugging Face Port
EXPOSE 7860
ENV PORT=7860

CMD ["bash", "main.sh"]
