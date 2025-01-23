#!/bin/bash

# 颜色设置
RESET="\033[0m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
BOLD="\033[1m"

# 常量定义
SCRIPT_DIR=$(dirname "$(realpath "$0")")
VIDEOS_DIR="$SCRIPT_DIR/videos"        # 视频目录
STREAM_SCRIPT_NAME="stream.sh"
STREAM_SCRIPT_PATH="$SCRIPT_DIR/$STREAM_SCRIPT_NAME"
MAIN_SCRIPT_NAME="bilibili_live_manager.sh"
MAIN_SCRIPT_PATH="$SCRIPT_DIR/$MAIN_SCRIPT_NAME"
GITHUB_MAIN_SCRIPT_URL="https://ghfast.top/https://raw.githubusercontent.com/lujih/bilibili_live/main/bilibili_live_manager.sh"

# 打印分隔符
print_separator() {
    echo -e "\n${BLUE}============================================${RESET}"
}

# 打印标题
print_title() {
    echo -e "${BOLD}${YELLOW}$1${RESET}"
    print_separator
}

# 初始化文件夹
setup_folders() {
    print_title "初始化文件夹"
    mkdir -p "$VIDEOS_DIR"
    echo -e "${GREEN}文件夹初始化完成：${RESET}"
    echo "- 视频文件夹：$VIDEOS_DIR"
}

# 安装依赖
install_dependencies() {
    print_title "安装必要依赖"
    echo -e "${YELLOW}正在安装依赖...${RESET}"
    if ! apt update; then
        echo -e "${RED}更新软件源失败，请检查网络连接！${RESET}"
        exit 1
    fi
    if ! apt install -y ffmpeg screen curl; then
        echo -e "${RED}依赖安装失败，请手动安装 ffmpeg, screen 和 curl！${RESET}"
        exit 1
    fi
    echo -e "${GREEN}依赖安装完成！${RESET}"
}

# 本地生成推流脚本
generate_stream_script() {
    print_title "生成推流脚本"
    cat << 'EOF' > "$STREAM_SCRIPT_PATH"
#!/bin/bash

# 哔哩哔哩推流脚本
STREAM_URL="$1"
VIDEO_DIR="$2"

if [ -z "$STREAM_URL" ]; then
    echo -e "未提供推流地址！"
    exit 1
fi

echo -e "推流地址：$STREAM_URL"
echo -e "视频目录：$VIDEO_DIR"

# 检查视频目录是否存在
if [ ! -d "$VIDEO_DIR" ]; then
    echo -e "视频目录不存在：$VIDEO_DIR"
    exit 1
fi

# 推流循环
while true; do
    video_files=("$VIDEO_DIR"/*)
    video_count=${#video_files[@]}

    if [ $video_count -eq 0 ]; then
        echo -e "视频目录为空，请添加视频后重试..."
        sleep 10
        continue
    fi

    for video in "${video_files[@]}"; do
        if [ -f "$video" ]; then
            echo -e "正在推流文件：$video"
            
            # 使用 copy 参数避免转码，直接推流
            ffmpeg -re -i "$video" \
                   -c:v copy -c:a copy \
                   -f flv "$STREAM_URL" || {
                echo -e "推流文件 $video 时发生错误，跳过..."
                continue
            }
        fi
    done

    echo -e "所有视频推流完成，将重新从第一个视频开始..."
done
EOF
    chmod +x "$STREAM_SCRIPT_PATH"
    echo -e "${GREEN}推流脚本已生成：$STREAM_SCRIPT_PATH${RESET}"
}

# 配置并启动推流
start_stream() {
    print_title "开始推流"
    echo -e "${YELLOW}请输入哔哩哔哩推流地址（包括直播码）：${RESET}"
    read -r STREAM_URL
    if [ -z "$STREAM_URL" ]; then
        echo -e "${RED}推流地址不能为空！${RESET}"
        return
    fi

    # 简单的推流地址格式验证
    if [[ ! "$STREAM_URL" =~ ^rtmp://[a-zA-Z0-9./?=&_-]+$ ]]; then
        echo -e "${RED}推流地址格式不正确，请检查！${RESET}"
        return
    fi

    # 生成推流脚本
    generate_stream_script "$STREAM_URL" "$VIDEOS_DIR"

    # 启动推流服务
    echo -e "${GREEN}启动推流服务...${RESET}"
    screen -dmS live_stream bash "$STREAM_SCRIPT_PATH" "$STREAM_URL" "$VIDEOS_DIR"
    echo -e "${GREEN}推流已启动，使用 'screen -r live_stream' 查看日志。${RESET}"
}

# 停止推流
stop_stream() {
    print_title "停止推流"
    echo -e "${YELLOW}停止推流服务...${RESET}"
    screen_sessions=$(screen -ls | grep "\.live_stream" | awk '{print $1}')
    
    if [ -z "$screen_sessions" ]; then
        echo -e "${RED}没有检测到正在运行的推流会话。${RESET}"
        return
    fi

    for session in $screen_sessions; do
        echo -e "${YELLOW}正在停止会话：$session${RESET}"
        screen -S "$session" -X quit
    done

    echo -e "${GREEN}所有推流会话已停止。${RESET}"
}

# 更新主脚本
update_scripts() {
    print_title "检查并更新主脚本"
    echo -e "${YELLOW}正在从 GitHub 仓库拉取最新的主脚本...${RESET}"
    curl -L "$GITHUB_MAIN_SCRIPT_URL" -o "$MAIN_SCRIPT_PATH" || {
        echo -e "${RED}主脚本更新失败，请检查网络连接！${RESET}"
        return
    }
    
    chmod +x "$MAIN_SCRIPT_PATH"
    echo -e "${GREEN}主脚本已成功更新！${RESET}"
    echo -e "${YELLOW}正在重启脚本...${RESET}"
    
    exec bash "$MAIN_SCRIPT_PATH"
}

# 卸载脚本及其依赖
uninstall_script() {
    print_title "卸载脚本及依赖工具"
    echo -e "${YELLOW}即将卸载以下内容：${RESET}"
    echo "- 脚本本身"
    echo "- 所有相关依赖（ffmpeg、screen、curl）"
    echo "- 文件夹：$VIDEOS_DIR"

    read -p "确认卸载吗？(y/N): " confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        echo -e "${YELLOW}正在卸载依赖工具...${RESET}"
        apt-get remove --purge -y ffmpeg screen curl || {
            echo -e "${RED}依赖卸载失败，请手动卸载！${RESET}"
        }

        rm -rf "$VIDEOS_DIR" "$SCRIPT_DIR/$STREAM_SCRIPT_NAME" "$SCRIPT_DIR/$MAIN_SCRIPT_NAME"
        
        echo -e "${GREEN}卸载完成！${RESET}"
    else
        echo -e "${RED}取消卸载操作。${RESET}"
    fi
}

# 主菜单
main_menu() {
    while true; do
        clear
        print_title "哔哩哔哩直播推流管理脚本"

        echo -e "${GREEN}请选择操作：${RESET}"
        echo -e "${YELLOW}1)${RESET} 安装依赖"
        echo -e "${YELLOW}2)${RESET} 检查更新"
        echo -e "${YELLOW}3)${RESET} 开始推流"
        echo -e "${YELLOW}4)${RESET} 停止推流"
        echo -e "${YELLOW}5)${RESET} 卸载脚本"
        echo -e "${YELLOW}6)${RESET} 退出"

        print_separator

        read -p "请输入选项编号：" REPLY

        case $REPLY in
        1) install_dependencies ;;
        2) update_scripts ;;
        3) start_stream ;;
        4) stop_stream ;;
        5) uninstall_script ;;
        6) exit 0 ;;
        *) echo -e "${RED}无效选择，请重新输入！${RESET}" ;;
        esac
    done
}

# 执行主菜单
setup_folders
main_menu
