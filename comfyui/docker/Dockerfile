FROM python:3.12-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    ffmpeg \
    git \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home/ubuntu

RUN python -m pip install --upgrade pip setuptools wheel
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

ARG TIMESTAMP=YYYYMMDD_HHMMSS
RUN echo "$TIMESTAMP" >/build_timestamp

RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /home/ubuntu/ComfyUI
WORKDIR /home/ubuntu/ComfyUI
RUN pip install -r requirements.txt

EXPOSE 8188

CMD ["bash", "-lc", "cd /home/ubuntu/ComfyUI && python main.py --listen 0.0.0.0 --port 8188"]
