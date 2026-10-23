#!/usr/bin/env bash
set -euo pipefail
trap 'rc=$?; printf "\nPMW 安装失败：setup.sh 第 %s 行，退出码 %s\n" "$LINENO" "$rc" >&2; exit "$rc"' ERR
export DEBIAN_FRONTEND=noninteractive
# RunPod images may enable an optional downloader outside this isolated venv.
# Use the standard Hub downloader without requiring hf_transfer.
export HF_HUB_ENABLE_HF_TRANSFER=0
RVC_ROOT="${RVC_ROOT:-/workspace/RVC}"
RVC_COMMIT=81eed5e8f68b6bed1789f682fe78cdd324495afc
echo "[PMW 1/6] 安装系统依赖"
apt-get update
apt-get install -y git ffmpeg unzip tmux build-essential python3.12 python3.12-venv python3.12-dev libsndfile1 libportaudio2
echo "[PMW 2/6] 获取固定版本 RVC 源码"
if [ ! -d "$RVC_ROOT/.git" ]; then
  git clone https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI.git "$RVC_ROOT"
fi
cd "$RVC_ROOT"
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo 'Tracked RVC source changed; refusing to overwrite it.' >&2
  exit 1
fi
git checkout --detach "$RVC_COMMIT"
echo "[PMW 3/6] 创建 Python 3.12 环境并安装 PyTorch"
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip 'setuptools>=75,<81' wheel
# Default: RTX 4090 / 3090 / A-series. RTX 50-series uses CUDA_FLAVOR=cu128.
CUDA_FLAVOR="${CUDA_FLAVOR:-cu118}"
case "$CUDA_FLAVOR" in cu118|cu128) ;; *) echo 'Use cu118 or cu128'; exit 1;; esac
python -m pip install "torch==2.7.1+$CUDA_FLAVOR" "torchaudio==2.7.1+$CUDA_FLAVOR" \
  --index-url "https://download.pytorch.org/whl/$CUDA_FLAVOR" --extra-index-url https://pypi.org/simple
python - "$CUDA_FLAVOR" <<'PY'
from pathlib import Path
import sys
p = Path(f'requirments_{sys.argv[1]}_py312.txt')
s = p.read_text().replace('https://mirrors.pku.edu.cn/pypi/simple', 'https://pypi.org/simple')
s = s.replace('https://mirrors.nju.edu.cn/pytorch/whl/', 'https://download.pytorch.org/whl/')
Path('/workspace/rvc-requirements.txt').write_text(s)
PY
echo "[PMW 4/6] 安装 RVC Python 依赖"
python -m pip install -r /workspace/rvc-requirements.txt
python -m pip check
python - <<'PY'
import torch
print('Torch:', torch.__version__, 'CUDA:', torch.version.cuda)
import os
if os.environ.get('PMW_IMAGE_BUILD') != '1':
    assert torch.cuda.is_available(), 'CUDA unavailable. Check RunPod GPU and driver.'
    print('GPU:', torch.cuda.get_device_name(0))
PY
echo "[PMW 5/6] 下载基础模型和训练资源"
mkdir -p assets/weights assets/indices logs
python - <<'PY'
from huggingface_hub import HfApi, snapshot_download, hf_hub_download
from pathlib import Path
import zipfile
repo = 'lj1995/VoiceConversionWebUI'
revision = HfApi().model_info(repo).sha
Path('model_revision.txt').write_text(revision + '\n')
snapshot_download(repo, revision=revision, local_dir='assets',
    allow_patterns=['hubert_base/*', 'pretrained_v2/f0G40k.pth', 'pretrained_v2/f0D40k.pth'])
hf_hub_download(repo, 'rmvpe.pt', revision=revision, local_dir='assets/rmvpe')
p = hf_hub_download(repo, 'mute.zip', revision=revision, local_dir='.model-downloads')
with zipfile.ZipFile(p) as z:
    # Refuse archive path traversal before extracting official silence samples.
    root = Path('logs').resolve()
    for n in z.namelist():
        assert (root/n).resolve().is_relative_to(root), n
    z.extractall(root)
for p in ['assets/hubert_base/config.json', 'assets/hubert_base/pytorch_model.bin',
          'assets/rmvpe/rmvpe.pt', 'assets/pretrained_v2/f0G40k.pth',
          'assets/pretrained_v2/f0D40k.pth', 'logs/mute/0_gt_wavs/mute40k.wav',
          'logs/mute/3_feature768/mute.npy', 'logs/mute/2a_f0/mute.wav.npy',
          'logs/mute/2b-f0nsf/mute.wav.npy']:
    assert Path(p).is_file(), f'Missing required asset: {p}'
PY
echo "[PMW 6/6] 保存运行环境"
python -m pip freeze > /workspace/rvc-environment-lock.txt
echo 'Setup complete. Next: bash /workspace/rvc_runpod/run.sh'
