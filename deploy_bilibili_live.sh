#!/bin/bash

# 定义常量
SCRIPT_DIR=$(dirname "$(realpath "$0")")
ORIGINAL_DIR="$SCRIPT_DIR/original_videos"  # 原始视频文件夹
TRANSCODED_DIR="$SCRIPT_DIR/videos"        # 转码后视频文件夹
SCRIPT_NAME="stream.sh"
STREAM_URL=""

# 创建视频存放文件夹
setup_folders() {
    mkdir -p "$ORIGINAL_DIR"
    mkdir -p "$TRANSCODED_DIR"
    echo "原始视频文件夹：$ORIGINAL_DIR"
    echo "转码后视频文件夹：$TRANSCODED_DIR"
}

# 安装必要工具
install_dependencies() {
    echo "正在安装必要工具..."
    apt update && apt install -y ffmpeg screen || {
        echo "安装失败，请检查网络连接或包管理器配置！"
        exit 1
    }
    echo "工具安装完成。"
}

# 转码视频
transcode_video() {
    echo "正在扫描原始视频文件夹：$ORIGINAL_DIR"
    videos=("$ORIGINAL_DIR"/*)
    
    if [ ${#videos[@]} -eq 0 ]; then
        echo "未检测到原始视频，请将视频放入 $ORIGINAL_DIR 后重试！"
        return
    fi

    while true; do
        echo "检测到以下视频文件："
        for i in "${!videos[@]}"; do
            echo "$((i + 1)). ${videos[$i]}"
        done

        echo "请选择需要转码的视频序号（输入 0 返回主菜单）："
        read -r choice

        if [[ "$choice" == "0" ]]; then
            return
        elif [[ "$choice" -ge 1 && "$choice" -le "${#videos[@]}" ]]; then
            input_video="${videos[$((choice - 1))]}"
            echo "您选择了视频：$input_video"
            break
        else
            echo "无效选项，请重新输入！"
        fi
    done

    while true; do
        echo "请选择目标码率档次："
        echo "1. 低（500k）"
        echo "2. 中（1000k）"
        echo "3. 高（2000k）"
        read -r bitrate_choice

        case $bitrate_choice in
        1)
            bitrate="500k"
            break
            ;;
        2)
            bitrate="1000k"
            break
            ;;
        3)
            bitrate="2000k"
            break
            ;;
        *)
            echo "无效选项，请重新输入！"
            ;;
        esac
    done

    output_video="$TRANSCODED_DIR/$(basename "$input_video")"
    echo "开始转码，目标码率：$bitrate..."
    ffmpeg -i "$input_video" -b:v "$bitrate" -b:a 128k -vf "scale=1280:720" "$output_video" -y
    echo "转码完成，文件保存至：$output_video"
}

# 推流脚本生成
generate_stream_script() {
    echo "生成循环推流脚本..."
    cat > $SCRIPT_NAME <<EOF
#!/bin/bash

TRANSCODED_DIR="$TRANSCODED_DIR"
STREAM_URL="$STREAM_URL"

$(cat <<'END_SCRIPT'
while true; do
    echo "扫描视频文件夹..."
    videos=("$TRANSCODED_DIR"/*)

    if [ ${#videos[@]} -eq 0 ]; then
        echo "视频文件夹为空，等待 10 秒后重新扫描..."
        sleep 10
        continue
    fi

    echo "开始循环播放文件夹中的视频..."
    for video in "${videos[@]}"; do
        if [ -f "$video" ]; then
            echo "正在推流视频文件：$video"
            ffmpeg -re -i "$video" -vcodec libx264 -preset veryfast -tune zerolatency -acodec aac -threads 2 -f flv "$STREAM_URL" || {
                echo "推流过程中发生错误，跳过当前视频..."
            }
        else
            echo "检测到非视频文件，跳过：$video"
        fi
    done

    echo "所有视频已播放完毕，等待 5 秒后重新开始循环..."
    sleep 5
done
END_SCRIPT
)
EOF

    chmod +x $SCRIPT_NAME
    echo "循环推流脚本生成完成：$SCRIPT_DIR/$SCRIPT_NAME"
}

# 配置推流
configure_stream() {
    while true; do
        echo "请输入 B 站推流地址（包括密钥）："
        read -r STREAM_URL

        if [ -z "$STREAM_URL" ]; then
            echo "推流地址不能为空，请重新输入！"
        else
            break
        fi
    done

    # 生成推流脚本
    generate_stream_script

    # 启动推流
    echo "启动推流服务..."
    screen -dmS bilibili_live bash "$SCRIPT_DIR/$SCRIPT_NAME"

    if screen -list | grep -q "bilibili_live"; then
        echo "推流服务已成功启动！"
        echo "你可以通过以下命令查看日志："
        echo "screen -r bilibili_live"
    else
        echo "推流服务启动失败，请检查错误日志！"
    fi
}

# 停止推流
stop_stream() {
    echo "停止推流服务..."
    screen -S bilibili_live -X quit
    echo "推流服务已停止。"
}

# 主菜单
main_menu() {
    while true; do
        echo "============================="
        echo " Bilibili 无人直播管理工具"
        echo "============================="
        echo "1. 安装环境依赖"
        echo "2. 创建视频存放文件夹"
        echo "3. 转码视频（压缩码率）"
        echo "4. 配置并启动推流"
        echo "5. 停止推流"
        echo "6. 退出"
        echo "============================="
        echo "请输入选项（1-6）："
        read -r choice

        case $choice in
        1)
            install_dependencies
            ;;
        2)
            setup_folders
            ;;
        3)
            transcode_video
            ;;
        4)
            configure_stream
            ;;
        5)
            stop_stream
            ;;
        6)
            echo "退出工具。"
            exit 0
            ;;
        *)
            echo "无效选项，请重新输入！"
            ;;
        esac
    done
}

# 主程序入口
setup_folders
main_menu
