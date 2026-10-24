# Chicago-servern: samma Godot-projekt körs headless på Linux som auktoritativ WebSocket-server.
# Byggs av Render (se render.yaml och README). Godot laddas ned från den officiella releasen vid bygget.
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7.2
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates wget unzip libfontconfig1 \
 && rm -rf /var/lib/apt/lists/*
RUN wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -O /tmp/godot.zip \
 && unzip -q /tmp/godot.zip -d /tmp \
 && mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
 && chmod +x /usr/local/bin/godot \
 && rm /tmp/godot.zip

WORKDIR /app
COPY project.godot main.tscn ./
COPY scripts ./scripts
COPY assets ./assets
# importera resurserna en gång vid bygget så att starten går snabbt
RUN godot --headless --path /app --import || true

# Render sätter PORT (standard 10000); servern läser miljövariabeln PORT
ENV PORT=10000
EXPOSE 10000
CMD godot --headless --path /app -- --server --port=$PORT
