FROM eclipse-temurin:17-jre-focal

# Install basic tools
RUN apt-get update && apt-get install -y bash curl wget git python3 && rm -rf /var/lib/apt/lists/*

# Hugging Face User Setup
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user
WORKDIR /home/user/app

# Copy your repo files into the container
COPY --chown=user:user . .

# Set execution permissions
RUN chmod +x main.sh || true

# IMPORTANT: HF only allows 7860
EXPOSE 7860
ENV PORT=7860

CMD ["bash", "main.sh"]
