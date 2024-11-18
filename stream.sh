#!/bin/bash

while true; do
    for video in /bilibili_live/videos/*; do
        echo "正在推流视频文件：$video"
        ffmpeg -re -i "$video" -vcodec libx264 -preset veryfast -tune zerolatency -acodec aac -threads 2 -f flv "rtmp://live-push.bilivideo.com/live-bvc/?streamname=live_485962382_77000177&key=e02b8345e0d39a254a540758f9a4b7a9&schedule=rtmp&pflag=1"
    done
    echo "所有视频推流完成，5 秒后重新循环..."
    sleep 5
done
