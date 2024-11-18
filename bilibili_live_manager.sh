#!/bin/bash

# 常量定义
SCRIPT_DIR=$(dirname "$(realpath "$0")")
ORIGINAL_DIR="$SCRIPT_DIR/original_videos"  # 原始视频目录
TRANSCODED_DIR="$SCRIPT_DIR/videos"        # 转码后视频目录
STREAM_SCRIPT_NAME="stream.sh"
MAIN_SCRIPT_NAME="bilibili_live_manager.sh"
GITHUB_MAIN_SCRIPT_URL="https://ghp.ci/https://github.com/lujih/bilibili_live/raw/main/bilibili_live_manager.sh"
GITHUB_STREAM_SCRIPT_URL="https://ghp.ci/https://github.com/lujih/bilibili_live/raw/main/stream.sh"
STREAM_SCRIPT_PATH="$SCRIPT_DIR/$STREAM_SCRIPT_NAME"
MAIN_SCRIPT_PATH="$SCRIPT_DIR/$MAIN_SCRIPT_NAME"

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
    apt update && apt install -y ffmpeg screen curl || {
        echo "依赖安装失败，请检查网络连接！"
        exit 1
    }
    echo "依赖安装完成！"
}

# 检查并下载推流脚本
check_and_download_scripts() {
    if [ ! -f "$STREAM_SCRIPT_PATH" ]; then
        echo "推流脚本未检测到，正在从 GitHub 下载..."
        curl -L "$GITHUB_STREAM_SCRIPT_URL" -o "$STREAM_SCRIPT_PATH" || {
            echo "推流脚本下载失败，请检查网络连接！"
            exit 1
        }
    else
        echo "推流脚本已存在：$STREAM_SCRIPT_PATH"
    fi
    chmod +x "$STREAM_SCRIPT_PATH"
    echo "推流脚本准备完成！"
}

update_scripts() {
    echo "更新主脚本..."
    if [ -f "$MAIN_SCRIPT_PATH" ]; then
        chmod +w "$MAIN_SCRIPT_PATH"
    fi
    curl -L "$GITHUB_MAIN_SCRIPT_URL" -o "$MAIN_SCRIPT_PATH" || {
        echo "主脚本更新失败，请检查网络连接！"
        return
    }

    # 验证主脚本是否正确下载
    if ! grep -q "main_menu()" "$MAIN_SCRIPT_PATH"; then
        echo "主脚本下载失败，文件内容不完整！"
        return
    fi

    echo "更新推流脚本..."
    if [ -f "$STREAM_SCRIPT_PATH" ]; then
        chmod +w "$STREAM_SCRIPT_PATH"
    fi
    curl -L "$GITHUB_STREAM_SCRIPT_URL" -o "$STREAM_SCRIPT_PATH" || {
        echo "推流脚本更新失败，请检查网络连接！"
        return
    }

    chmod +x "$MAIN_SCRIPT_PATH" "$STREAM_SCRIPT_PATH"
    echo "脚本更新完成！正在重启..."
    exec bash "$MAIN_SCRIPT_PATH"
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

# 配置并启动推流（新增二级菜单）
start_stream() {
    echo "请选择推流平台："
    PS3="输入选项："
    platforms=("Bilibili" "斗鱼" "虎牙" "返回主菜单")
    select platform in "${platforms[@]}"; do
        case $platform in
        "Bilibili")
            platform_name="Bilibili"
            break
            ;;
        "斗鱼")
            platform_name="斗鱼"
            break
            ;;
        "虎牙")
            platform_name="虎牙"
            break
            ;;
        "返回主菜单")
            return
            ;;
        *)
            echo "无效选项，请重新选择！"
            ;;
        esac
    done

    echo "请输入 $platform_name 的推流地址（包括推流码）："
    read -r STREAM_URL
    if [ -z "$STREAM_URL" ]; then
        echo "推流地址不能为空！"
        return
    fi

    echo "启动 $platform_name 推流服务..."
    screen -dmS live_stream bash "$STREAM_SCRIPT_PATH" "$STREAM_URL"
    echo "$platform_name 推流已启动，使用 'screen -r live_stream' 查看日志。"
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

# 主菜单
main_menu() {
    while true; do
        clear
        echo "====================================="
        echo "        📺 多平台无人直播管理工具         "
        echo "====================================="
        echo "  1. 安装环境依赖"
        echo "  2. 初始化视频文件夹"
        echo "  3. 更新主脚本和推流脚本"
        echo "  4. 转码视频（压缩码率）"
        echo "  5. 启动推流服务"
        echo "  6. 停止推流服务"
        echo "  7. CPU 压力测试"
        echo "  8. 退出脚本"
        echo "====================================="
        echo "请输入选项（1-8）："
        read -r choice

        case $choice in
        1) install_dependencies ;;
        2) setup_folders ;;
        3) update_scripts ;;
        4) transcode_video ;;
        5) start_stream ;;
        6) stop_stream ;;
        7) cpu_stress_test ;;
        8) cd "$SCRIPT_DIR" && exit 0 ;;  # 返回脚本目录并退出
        *) echo "无效选项，请重新输入！" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 初始化操作并启动菜单
setup_folders
check_and_download_scripts
main_menu
