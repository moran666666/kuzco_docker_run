#!/bin/bash

###### 本脚本适用于linux系统N卡跑kuzco，根据实际情况修改 instance_array 数组的内容即可
###### 脚本功能： 添加了3分钟运行一次本脚本的周期性任务，仅需要手动执行一次本脚本
###### 运行本脚本的前提：安装了NVIDIA驱动、安装了docker、安装且配置了NVIDIA Container Toolkit


# 自定义实例数组 instance_array ，每1行存储1个docker实例，可以填写其他机器的实例，本机器通过$hostname筛选仅运行属于自己的实例
#【docker_name=$(hostname)-显卡索引-本显卡实例】，按自己显卡的实际情况仅修改 “显卡索引”、“本显卡实例”，$(hostname)千万不要改动
#【woker=填写自己账号建立的矿工worker项】
#【code=填写自己账号建立的矿工code项】

instance_array=(
"docker_name=$(hostname)-0-0 woker=67kZMfpU6o0uDWkdufKXX code=7aaf6ce1-ae22-4c88-b7dd-07d545a116a0"
"docker_name=$(hostname)-1-0 woker=67kZMfpU6o0uDWkdufKXX code=7aaf6ce1-ae22-4c88-b7dd-07d545a116a0"
"docker_name=$(hostname)-2-0 woker=67kZMfpU6o0uDWkdufKXX code=7aaf6ce1-ae22-4c88-b7dd-07d545a116a0")

vram_require_size=8000          # 按官方要求设置每个实例的显存大小为8G，如果个人觉得6G可行请自行改小，这样有12G显存的显卡能跑2个实例，否则只能跑1个实例

################################################仅修改上面的内容，下面的不用修改############################################################

instance_array_length=${#instance_array[@]}
docker_run_info=$(docker ps -a  | grep -v "NAME")
gpus_info=$(nvidia-smi --query-gpu=index,memory.total --format=csv,noheader,nounits)      # 定义 gpus_info 变量，存储多行gpu的索引、显存信息内容（使用换行符分隔）
echo "$gpus_info" | while IFS= read -r line; do                                           # 将 gpus_info 变量的内容处理为逐行输出，即轮循每个gpu的信息
        gpu_index=$(echo "$line" | awk -v col=1 '{print $col}' | xargs | tr -d ",")       # 使用 awk 提取第1列，使用xargs去掉前后空格，截掉逗号“,”字符，最后输出单个 gpu 的索引值
        vram_size=$(echo "$line" | awk -v col=2 '{print $col}' | xargs)                   # 使用 awk 提取第2列，使用xargs去掉前后空格，最后输出单个 gpu 的显存大小

        device_index="device=$gpu_index"
        container_count=$(( vram_size / vram_require_size ))
        for ((i=0; i<container_count; i++)); do
                docker_name="$(hostname)-$gpu_index-$i"

                if [[ "$docker_run_info" == *"$docker_name"* ]]; then
                    echo "存在docker容器:"${docker_name}
                else
                    echo "启动docker容器:"${docker_name}
                    woker_id=""
                    code=""
                    for ((i=0; i<instance_array_length; i++)); do
                        instance_str=${instance_array[i]}
                            if [[ "$instance_str" == *"$docker_name"* ]]; then            # 从自定义的实例数组中查找--worker、--code选项的值
                                    echo "找到匹配自定义的worker..."
                                    woker_id=$(echo "$instance_str" | awk -v col=2 '{print $col}' | xargs | awk -F'=' '{print $2}')
                                    code=$(echo "$instance_str" | awk -v col=3 '{print $col}' | xargs | awk -F'=' '{print $2}')
                                    break
                            fi
                    done
                    docker run --name $docker_name --rm --runtime=nvidia --gpus "$device_index" -d kuzcoxyz/worker:latest --worker $woker_id --code $code
                fi
        done
done

new_cron_job="*/3 * * * * cd $(pwd) && bash $(basename "$0")"   # 定义新的 cron 任务（设置了3分钟运行一次本脚本）
if crontab -l | grep -Fq "$new_cron_job"; then                  # 检查 cron 任务是否已经存在,不存在则将新任务添加到现有的 crontab
    echo "周期性任务已存在: $new_cron_job"
else
    (crontab -l; echo "$new_cron_job") | crontab -
    echo "添加新的周期性任务: $new_cron_job"
fi
