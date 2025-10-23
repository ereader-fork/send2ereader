# Use Debian slim to support glibc and i386 libs needed by kindlegen
FROM node:lts-slim

# Faster, noninteractive apt
ENV DEBIAN_FRONTEND=noninteractive
# Ensure pipx-installed apps are on PATH
ENV PATH="/root/.local/bin:${PATH}"
# Production install for Node
ENV NODE_ENV=production

WORKDIR /usr/src/app

# --- System deps, 32-bit libs for kindlegen, curl, python/pipx, and optional PDF utils ---
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates curl wget xz-utils \
    libc6:i386 libstdc++6:i386 \
    python3 python3-pip python3-venv \
    pipx \
    ghostscript poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# --- kepubify (glibc) ---
ARG KEPUBIFY_VER=v4.0.4
RUN set -eux; \
    curl -L --fail -o /usr/local/bin/kepubify \
    "https://github.com/pgaskin/kepubify/releases/download/${KEPUBIFY_VER}/kepubify-linux-64bit" \
    && chmod +x /usr/local/bin/kepubify

# --- kindlegen (i386) ---
# (Pinned to specific commit and sha256; update if the upstream changes)
ARG KINDLEGEN_TGZ=kindlegen_linux_2.6_i386_v2_9.tar.gz
ARG KINDLEGEN_URL=https://github.com/zzet/fp-docker/raw/f2b41fb0af6bb903afd0e429d5487acc62cb9df8/${KINDLEGEN_TGZ}
ARG KINDLEGEN_SHA=9828db5a2c8970d487ada2caa91a3b6403210d5d183a7e3849b1b206ff042296
RUN set -eux; \
    curl -L --fail -o "${KINDLEGEN_TGZ}" "${KINDLEGEN_URL}" \
    && echo "${KINDLEGEN_SHA}  ${KINDLEGEN_TGZ}" | sha256sum -c - \
    && mkdir -p /opt/kindlegen \
    && tar -xvf "${KINDLEGEN_TGZ}" -C /opt/kindlegen \
    && cp /opt/kindlegen/kindlegen /usr/local/bin/kindlegen \
    && chmod +x /usr/local/bin/kindlegen \
    && rm -rf /opt/kindlegen "${KINDLEGEN_TGZ}"

# --- python cli via pipx ---
RUN pipx install pdfCropMargins

# --- Node deps (use npm ci for reproducibility) ---
COPY package*.json ./
RUN npm ci --omit=dev

# --- App code ---
COPY . ./

# Prepare uploads dir and permissions; use the node user
RUN mkdir -p /usr/src/app/uploads \
    && chown -R node:node /usr/src/app

USER node

EXPOSE 3001
CMD ["npm", "start"]