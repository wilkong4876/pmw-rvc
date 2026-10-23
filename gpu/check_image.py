"""Validate PMW image before accepting a task; no downloads or installations."""
import json
import os
from pathlib import Path
import subprocess
import sys

VERSION = 'pmw-rvc-cu128-v1'
ROOT = Path('/opt/pmw/RVC')
MARKER = Path('/opt/pmw/image.json')

def check(build=False):
    import torch
    import aiohttp
    import demucs
    import transformers
    import soundfile
    expected = '81eed5e8f68b6bed1789f682fe78cdd324495afc'
    commit = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    if commit != expected:
        raise RuntimeError('预装镜像 RVC 版本不匹配')
    for name in ('assets/hubert_base/config.json', 'assets/hubert_base/pytorch_model.bin',
                 'assets/rmvpe/rmvpe.pt', 'assets/pretrained_v2/f0G40k.pth',
                 'assets/pretrained_v2/f0D40k.pth', 'logs/mute/0_gt_wavs/mute40k.wav',
                 'logs/mute/3_feature768/mute.npy', 'logs/mute/2a_f0/mute.wav.npy',
                 'logs/mute/2b-f0nsf/mute.wav.npy'):
        if not (ROOT / name).is_file():
            raise RuntimeError('预装镜像缺少资源：' + name)
    if not list(Path('/opt/pmw/torch/hub/checkpoints').glob('*.th')):
        raise RuntimeError('预装镜像缺少 Demucs 权重')
    subprocess.run(['ffmpeg', '-version'], check=True, stdout=subprocess.DEVNULL)
    if build:
        MARKER.write_text(json.dumps({'version': VERSION, 'rvc': commit, 'torch': torch.__version__}))
    else:
        if json.loads(MARKER.read_text()).get('version') != VERSION:
            raise RuntimeError('预装镜像版本不匹配，请重新构建')
        if not torch.cuda.is_available():
            raise RuntimeError('预装镜像未检测到 CUDA GPU')
    print('PMW 预装环境检查通过：' + VERSION, flush=True)

if __name__ == '__main__':
    check('--build' in sys.argv)
