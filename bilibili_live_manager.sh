#!/bin/bash

# 常量定义
SCRIPT_DIR=$(dirname "$(realpath "$0")")
ORIGINAL_DIR="$SCRIPT_DIR/original_videos"  # 原始视频目录
TRANSCODED_DIR="$SCRIPT_DIR/videos"        # 转码后视频目录
STREAM_SCRIPT_NAME="stream.sh"
STREAM_SCRIPT_PATH="$SCRIPT_DIR/$STREAM_SCRIPT_NAME"
MAIN_SCRIPT_NAME="bilibili_live_manager.sh"
MAIN_SCRIPT_PATH="$SCRIPT_DIR/$MAIN_SCRIPT_NAME"
GITHUB_MAIN_SCRIPT_URL="https://raw.githubusercontent.com/lujih/bilibili_live/main/bilibili_live_manager.sh"

# 初始化文件夹
setup_folders() {
    mkdir -p "$ORIGINAL_DIR"
    mkdir -p "$TRANSCODED_DIR"
    echo "文件夹初始化完成："
    echo "- 原始视频文件夹：$ORIGINAL_DIR"
    echo "- 转码后视频文件夹：$TRANSCODED_DIR"
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

while true; do
    for video in "$VIDEO_DIR"/*; do
        if [ -f "$video" ]; then
            echo "正在推流文件：$video"
            ffmpeg -re -i "$video" -c:v copy -c:a copy -f flv "$STREAM_URL"
        else
            echo "视频目录中没有文件，等待添加视频..."
            sleep 10
        fi
    done
done
EOF
    chmod +x "$STREAM_SCRIPT_PATH"
    echo "推流脚本已生成：$STREAM_SCRIPT_PATH"
}

# 视频转码
transcode_video() {
    echo "扫描原始视频文件夹..."
    videos=("$ORIGINAL_DIR"/*)

    if [ ${#videos[@]} -eq 0 ]; then
        echo "未检测到原始视频，请将视频放入 $ORIGINAL_DIR 后重试！"
        return
    fi

    echo "请选择需要转码的视频："
    select video in "${videos[@]}"; do
        if [ -n "$video" ]; then
            echo "选择的视频是：$video"
            break
        else
            echo "无效选择，请重新输入！"
        fi
    done

    echo "选择目标码率："
    PS3="输入选项："
    select bitrate in "低（500k）" "中（1000k）" "高（2000k）"; do
        case $REPLY in
        1) bitrate="500k"; break ;;
        2) bitrate="1000k"; break ;;
        3) bitrate="2000k"; break ;;
        *) echo "无效选项，请重新输入！" ;;
        esac
    done

    output_video="$TRANSCODED_DIR/$(basename "$video")"
    echo "开始转码，目标码率：$bitrate..."
    ffmpeg -i "$video" -b:v "$bitrate" -b:a 128k -vf scale=1280:720 "$output_video" -y
    echo "转码完成，文件保存至：$output_video"
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
    screen -S live_stream -X quit
    echo "推流服务已停止。"
}

# CPU 压力测试
cpu_stress_test() {
    echo "开始 CPU 压力测试..."
    for bitrate in 500k 1000k 2000k; do
        test_video="$TRANSCODED_DIR/test_$bitrate.mp4"
        ffmpeg -f lavfi -i testsrc=duration=10:size=1280x720:rate=30 -b:v "$bitrate" -y "$test_video"
        echo "生成测试视频：$test_video （码率：$bitrate）"
    done
    echo "请观察 CPU 使用率，选择合适的码率进行推流。"
}

# 更新主脚本
update_main_script() {
    echo "正在更新主脚本..."
    curl -L "$GITHUB_MAIN_SCRIPT_URL" -o "$MAIN_SCRIPT_PATH" || {
        echo "主脚本更新失败，请检查网络连接！"
        return
    }
    chmod +x "$MAIN_SCRIPT_PATH"
    echo "主脚本更新完成！正在重启脚本..."
    exec bash "$MAIN_SCRIPT_PATH"
}

# 卸载功能
uninstall_script() {
    echo "正在卸载脚本和相关文件..."
    rm -rf "$ORIGINAL_DIR" "$TRANSCODED_DIR" "$STREAM_SCRIPT_PATH" "$MAIN_SCRIPT_PATH"
    echo "卸载完成！"
    exit 0
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo "====================================="
        echo "        📺 哔哩哔哩无人直播管理工具        "
        echo "====================================="
        echo "  1. 安装环境依赖"
        echo "  2. 初始化视频文件夹"
        echo "  3. 转码视频（压缩码率）"
        echo "  4. 启动推流服务"
        echo "  5. 停止推流服务"
        echo "  6. CPU 压力测试"
        echo "  7. 更新主脚本"
        echo "  8. 卸载脚本"
        echo "  9. 退出脚本"
        echo "====================================="
        echo "请输入选项（1-9）："
        read -r choice

        case $choice in
        1) install_dependencies ;;
        2) setup_folders ;;
        3) transcode_video ;;
        4) start_stream ;;
        5) stop_stream ;;
        6) cpu_stress_test ;;
        7) update_main_script ;;
        8) uninstall_script ;;
        9) echo "退出脚本。"; exit 0 ;;
        *) echo "无效选项，请重新输入！" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 初始化操作并启动菜单
setup_folders
main_menu
