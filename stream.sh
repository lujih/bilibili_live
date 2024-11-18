#!/bin/bash

# 推流地址
STREAM_URL="__STREAM_URL__"

# 推流逻辑
while true; do
    for video in /bilibili_live/videos/*; do
        echo "正在推流视频文件：$video"
        ffmpeg -re -i "$video" -vcodec libx264 -preset veryfast -tune zerolatency -acodec aac -threads 2 -f flv "$STREAM_URL"
    done
    echo "所有视频推流完成，5 秒后重新循环..."
    sleep 5
done
