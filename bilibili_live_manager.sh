#!/bin/bash

# 常量定义
SCRIPT_DIR=$(dirname "$(realpath "$0")")
ORIGINAL_DIR="$SCRIPT_DIR/original_videos"  # 原始视频目录
TRANSCODED_DIR="$SCRIPT_DIR/videos"        # 视频目录（无需转码）
STREAM_SCRIPT_NAME="stream.sh"
STREAM_SCRIPT_PATH="$SCRIPT_DIR/$STREAM_SCRIPT_NAME"
MAIN_SCRIPT_NAME="bilibili_live_manager.sh"
MAIN_SCRIPT_PATH="$SCRIPT_DIR/$MAIN_SCRIPT_NAME"
GITHUB_MAIN_SCRIPT_URL="https://gh.llkk.cc/https://raw.githubusercontent.com/lujih/bilibili_live/main/bilibili_live_manager.sh"

# 初始化文件夹
setup_folders() {
    mkdir -p "$ORIGINAL_DIR"
    mkdir -p "$TRANSCODED_DIR"
    echo "文件夹初始化完成："
    echo "- 原始视频文件夹：$ORIGINAL_DIR"
    echo "- 视频文件夹：$TRANSCODED_DIR"
}

# 安装依赖
install_dependencies() {
    echo "正在安装必要依赖..."
    apt update && apt install -y ffmpeg screen || {
        echo "依赖安装失败，请检查网络连接！"
        exit 1
    }
    echo "依赖安装完成！"
}

# 本地生成推流脚本
generate_stream_script() {
    cat << 'EOF' > "$STREAM_SCRIPT_PATH"
#!/bin/bash

# 哔哩哔哩推流脚本
STREAM_URL="$1"
VIDEO_DIR="$(dirname "$(realpath "$0")")/videos"

if [ -z "$STREAM_URL" ]; then
    echo "未提供推流地址！"
    exit 1
fi

echo "推流地址：$STREAM_URL"
echo "视频目录：$VIDEO_DIR"

# 检查视频目录是否存在
if [ ! -d "$VIDEO_DIR" ]; then
    echo "视频目录不存在：$VIDEO_DIR"
    exit 1
fi

# 推流循环
while true; do
    video_files=("$VIDEO_DIR"/*)
    video_count=${#video_files[@]}

    if [ $video_count -eq 0 ]; then
        echo "视频目录为空，请添加视频后重试..."
        sleep 10
        continue
    fi

    for video in "${video_files[@]}"; do
        if [ -f "$video" ]; then
            echo "正在推流文件：$video"
            ffmpeg -re -i "$video" -c copy -f flv "$STREAM_URL" || {
                echo "推流文件 $video 时发生错误，跳过..."
                continue
            }
        fi
    done

    echo "所有视频推流完成，将重新从第一个视频开始..."
done
EOF
    chmod +x "$STREAM_SCRIPT_PATH"
    echo "推流脚本已生成：$STREAM_SCRIPT_PATH"
}

# 配置并启动推流
start_stream() {
    echo "请输入哔哩哔哩推流地址（包括直播码）："
    read -r STREAM_URL
    if [ -z "$STREAM_URL" ]; then
        echo "推流地址不能为空！"
        return
    fi

    # 生成推流脚本
    generate_stream_script

    # 启动推流服务
    echo "启动推流服务..."
    screen -dmS live_stream bash "$STREAM_SCRIPT_PATH" "$STREAM_URL"
    echo "推流已启动，使用 'screen -r live_stream' 查看日志。"
}

# 停止推流
stop_stream() {
    echo "停止推流服务..."
    screen_sessions=$(screen -ls | grep "\.live_stream" | awk '{print $1}')
    
    if [ -z "$screen_sessions" ]; then
        echo "没有检测到正在运行的推流会话。"
        return
    fi

    for session in $screen_sessions; do
        echo "正在停止会话：$session"
        screen -S "$session" -X quit
    done

    echo "所有推流会话已停止。"
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo "====================================="
        echo "        📺 多平台无人直播管理工具         "
        echo "====================================="
        echo "  1. 安装环境依赖"
        echo "  2. 初始化视频文件夹"
        echo "  3. 启动推流服务"
        echo "  4. 停止推流服务"
        echo "  5. 退出脚本"
        echo "====================================="
        echo "请输入选项（1-5）："
        read -r choice

        case $choice in
        1) install_dependencies ;;
        2) setup_folders ;;
        3) start_stream ;;
        4) stop_stream ;;
        5) echo "退出脚本。"; exit 0 ;;
        *) echo "无效选项，请重新输入！" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 初始化操作并启动菜单
setup_folders
main_menu
