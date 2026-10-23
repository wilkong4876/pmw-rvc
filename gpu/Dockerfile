# Build context: repository root. No task audio, user models or credentials.
FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404
ENV RVC_ROOT=/opt/pmw/RVC CUDA_FLAVOR=cu128 HF_HUB_ENABLE_HF_TRANSFER=0 TORCH_HOME=/opt/pmw/torch
COPY gpu/setup.sh /opt/pmw/setup.sh
RUN PMW_IMAGE_BUILD=1 bash /opt/pmw/setup.sh
RUN /opt/pmw/RVC/.venv/bin/python -m pip install aiohttp demucs==4.0.1 && /opt/pmw/RVC/.venv/bin/python -m pip check
# Bake Demucs separation weights too; loading a mixed song must not fetch them.
RUN /opt/pmw/RVC/.venv/bin/python -c "from demucs.pretrained import get_model; get_model('htdemucs')"
COPY gpu/check_image.py /opt/pmw/check_image.py
RUN /opt/pmw/RVC/.venv/bin/python /opt/pmw/check_image.py --build
WORKDIR /workspace
