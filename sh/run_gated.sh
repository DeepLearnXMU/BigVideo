#! /usr/bin/bash
set -e

device=4
task=multi30k-en2de
image_feat=vit_base_patch16_384
mask_data=mask0
DATA=/home/sata/kly/fairseq_mmt/data-bin
IMAGE=/home/sata/kly/fairseq_mmt/img_feature

if [ ! -d $save_dir ]; then
        mkdir -p $save_dir
fi

if [ $task == 'multi30k-en2de' ]; then
	src_lang=en
	tgt_lang=de
	if [ $mask_data == "mask0" ]; then
        	data_dir=$DATA/multi30k.en-de
	elif [ $mask_data == "mask1" ]; then
	        data_dir=$DATA/multi30k.en-de.mask1
	elif [ $mask_data == "mask2" ]; then
      		data_dir=$DATA/multi30k.en-de.mask2
	elif [ $mask_data == "mask3" ]; then
	        data_dir=$DATA/multi30k.en-de.mask3
	elif [ $mask_data == "mask4" ]; then
	        data_dir=$DATA/multi30k.en-de.mask4
        elif [ $mask_data == "maskc" ]; then
	        data_dir=$DATA/multi30k.en-de.maskc
        elif [ $mask_data == "maskp" ]; then
	        data_dir=$DATA/multi30k.en-de.maskp
	fi
elif [ $task == 'multi30k-en2fr' ]; then
	src_lang=en
	tgt_lang=fr
	if [ $mask_data == "mask0" ]; then
        	data_dir=$DATA/multi30k.en-fr
	elif [ $mask_data == "mask1" ]; then
	        data_dir=$DATA/multi30k.en-fr.mask1
	elif [ $mask_data == "mask2" ]; then
      		data_dir=$DATA/multi30k.en-fr.mask2
	elif [ $mask_data == "mask3" ]; then
	        data_dir=$DATA/multi30k.en-fr.mask3
	elif [ $mask_data == "mask4" ]; then
	        data_dir=$DATA/multi30k.en-fr.mask4
        elif [ $mask_data == "maskc" ]; then
	        data_dir=$DATA/multi30k.en-fr.maskc
        elif [ $mask_data == "maskp" ]; then
	        data_dir=$DATA/multi30k.en-fr.maskp
	fi
fi

criterion=label_smoothed_cross_entropy
fp16=1 #0
lr=0.005
warmup=2000
max_tokens=4096
update_freq=2
keep_last_epochs=10
patience=10
max_update=8000
dropout=0.3
seed=1

arch=image_multimodal_transformer_gated_tiny

gpu_num=`echo "$device" | awk '{split($0,arr,",");print length(arr)}'`

name=mmt_arch${arch}_imgFeature${image_feat}_mask${mask_data}_SAAdp${SA_attention_dropout}_SAIdp${SA_image_dropout}_tgt${tgt_lang}_lr${lr}_wu${warmup}_mu${max_update}_seed${seed}_gpu${gpu_num}_mt${max_tokens}_acc${update_freq}_patience${patience}

output_dir=/home/sata/kly/fairseq_mmt/output/image_mmt/${name}


mkdir -p $output_dir



if [ $image_feat == "vit_tiny_patch16_384" ]; then
	image_feat_path=$IMAGE/$image_feat
	image_feat_dim=192
elif [ $image_feat == "vit_small_patch16_384" ]; then
	image_feat_path=$IMAGE/$image_feat
	image_feat_dim=384
elif [ $image_feat == "vit_base_patch16_384" ]; then
	image_feat_path=$IMAGE/$image_feat
	image_feat_dim=768
elif [ $image_feat == "vit_large_patch16_384" ]; then
	image_feat_path=$IMAGE/$image_feat
	image_feat_dim=1024
fi

# multi-feature
#image_feat_path=data/vit_large_patch16_384 data/vit_tiny_patch16_384
#image_feat_dim=1024 192

cp ${BASH_SOURCE[0]} $output_dir/train.sh

gpu_num=`echo "$device" | awk '{split($0,arr,",");print length(arr)}'`

cmd="fairseq-train $data_dir
  --save-dir $output_dir
  --distributed-world-size $gpu_num -s $src_lang -t $tgt_lang
  --arch $arch
  --dropout $dropout
  --criterion $criterion --label-smoothing 0.1
  --task image_mmt --image-feat-path $image_feat_path --image-feat-dim $image_feat_dim
  --optimizer adam --adam-betas '(0.9, 0.98)'
  --lr $lr --min-lr 1e-09 --lr-scheduler inverse_sqrt --warmup-init-lr 1e-07 --warmup-updates $warmup
  --max-tokens $max_tokens --update-freq $update_freq --max-update $max_update
  --seed $seed
  --find-unused-parameters
  --share-all-embeddings
  --patience $patience
  --keep-last-epochs $keep_last_epochs"

if [ $fp16 -eq 1 ]; then
cmd=${cmd}" --fp16 "
fi


export CUDA_VISIBLE_DEVICES=$device
cmd="nohup "${cmd}" > $output_dir/train.log 2>&1 &"
eval $cmd
tail -f $output_dir/train.log
