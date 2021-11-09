#!/bin/bash
source path.sh

gpus=0
stage=0
stop_stage=100

# with the following command, you can choice the stage range you want to run
# such as `./run.sh --stage 0 --stop-stage 0`
# this can not be mixed use with `$1`, `$2` ...
source ${MAIN_ROOT}/utils/parse_options.sh || exit 1

mkdir download

if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then
    # install PaddleGAN
    git clone https://github.com/PaddlePaddle/PaddleGAN.git
    pip install -e PaddleGAN/
fi

if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then 
    # download pretrained PaddleGAN model
    wget -P download https://paddlegan.bj.bcebos.com/models/wav2lip_hq.pdparams
fi 

if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
    # download pretrained tts models and unzip
    wget -P download https://paddlespeech.bj.bcebos.com/Parakeet/pwg_baker_ckpt_0.4.zip
    unzip -d download download/pwg_baker_ckpt_0.4.zip
    wget -P download https://paddlespeech.bj.bcebos.com/Parakeet/fastspeech2_nosil_baker_ckpt_0.4.zip
    unzip -d download download/fastspeech2_nosil_baker_ckpt_0.4.zip
fi

if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then
    # run tts
    CUDA_VISIBLE_DEVICES=${gpus} \
    python3 ${BIN_DIR}/synthesize_e2e.py \
        --fastspeech2-config=download/fastspeech2_nosil_baker_ckpt_0.4/default.yaml \
        --fastspeech2-checkpoint=download/fastspeech2_nosil_baker_ckpt_0.4/snapshot_iter_76000.pdz \
        --fastspeech2-stat=download/fastspeech2_nosil_baker_ckpt_0.4/speech_stats.npy \
        --pwg-config=download/pwg_baker_ckpt_0.4/pwg_default.yaml \
        --pwg-checkpoint=download/pwg_baker_ckpt_0.4/pwg_snapshot_iter_400000.pdz \
        --pwg-stat=download/pwg_baker_ckpt_0.4/pwg_stats.npy \
        --text=sentences.txt \
        --output-dir=output/wavs \
        --inference-dir=output/inference \
        --phones-dict=download/fastspeech2_nosil_baker_ckpt_0.4/phone_id_map.txt
    # output/inference is not needed here, which save the static models
    rm -rf output/inference
fi

if [ ${stage} -le  4 ] && [ ${stop_stage} -ge 4 ]; then
    # We only test one audio here, cause it's slow
    CUDA_VISIBLE_DEVICES=${gpus} \
    python3 PaddleGAN/applications/tools/wav2lip.py \
        --checkpoint_path download/wav2lip_hq.pdparams \
        --face Lamarr.png \
        --audio output/wavs/000.wav \
        --outfile output/tts_lips.mp4 \
        --face_enhancement
fi
