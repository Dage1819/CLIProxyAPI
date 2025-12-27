#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== CLIProxyAPI 管理脚本 ===${NC}"
echo "1. 启动/重启服务"
echo "2. 停止服务" 
echo "3. 重新构建并启动"
echo -e "${BLUE}================${NC}"
read -p "请选择 (1/2/3): " choice

# 基础配置
CLI_DIR="/root/cliproxyapi"          # 运行目录（小写）
EXECUTABLE="$CLI_DIR/cli-proxy-api"
REPO_URL="https://github.com/Dage1819/CLIProxyAPI.git"

# 工具函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查服务状态
check_service() {
    if curl -s --connect-timeout 2 http://localhost:8317/v1/health >/dev/null; then
        return 0
    else
        return 1
    fi
}

# 停止服务
stop_service() {
    log_info "停止服务..."
    
    pkill -f "cli-proxy-api" 2>/dev/null
    sleep 1
    
    if ps aux | grep -q "[c]li-proxy-api"; then
        pkill -9 -f "cli-proxy-api" 2>/dev/null
        sleep 1
    fi
    
    if ps aux | grep -q "[c]li-proxy-api"; then
        log_error "无法停止服务"
        return 1
    else
        log_success "服务已停止"
        return 0
    fi
}

# 启动服务
start_service() {
    log_info "启动服务..."
    
    if [ ! -f "$EXECUTABLE" ]; then
        log_error "未找到可执行文件: $EXECUTABLE"
        return 1
    fi
    
    chmod +x "$EXECUTABLE"
    cd "$CLI_DIR"
    
    nohup ./cli-proxy-api > cli-proxy-api.log 2>&1 &
    sleep 3
    
    if ps aux | grep -q "[c]li-proxy-api"; then
        log_success "服务启动成功"
        sleep 2
        if check_service; then
            log_success "服务运行正常"
        fi
        return 0
    else
        log_error "服务启动失败"
        return 1
    fi
}

# 重新构建（严格按照用户的三步流程）
rebuild_service() {
    log_info "开始重新构建服务..."
    
    # 1. 停止现有服务
    stop_service
    
    # 2. 检查Go环境
    if ! command -v go &> /dev/null; then
        log_error "Go未安装"
        echo "安装命令: apt update && apt install -y golang"
        return 1
    fi
    
    # 3. 进入运行目录
    cd "$CLI_DIR" || {
        log_error "无法进入目录: $CLI_DIR"
        return 1
    }
    
    # 4. 删除旧源码并重新克隆
    if [ -d "CLIProxyAPI" ]; then
        log_info "删除旧源码..."
        rm -rf CLIProxyAPI
    fi
    
    log_info "克隆源码 (GitHub: CLIProxyAPI)..."
    git clone "$REPO_URL" CLIProxyAPI
    if [ $? -ne 0 ]; then
        log_error "克隆失败"
        return 1
    fi
    
    # 进入源码目录
    cd CLIProxyAPI
    
    # 5. 构建编译
    log_info "构建编译..."
    
    # 设置代理加速
    export GOPROXY=https://goproxy.cn,direct
    export GO111MODULE=on
    
    # 下载依赖
    go mod download
    
    # 编译
    if go build -o cli-proxy-api ./cmd/server; then
        if [ -f "cli-proxy-api" ]; then
            log_success "编译成功"
        else
            log_error "未生成可执行文件"
            return 1
        fi
    else
        log_error "编译失败"
        return 1
    fi
    
    # 6. 拷贝文件到运行目录（/root/cliproxyapi）
    log_info "拷贝文件到运行目录..."
    
    # 备份旧文件
    if [ -f "../cli-proxy-api" ]; then
        mv "../cli-proxy-api" "../cli-proxy-api.backup"
    fi
    
    # 拷贝新文件
    cp cli-proxy-api ../
    
    # 返回运行目录
    cd ..
    
    log_success "构建完成"
    return 0
}

# 主逻辑
case $choice in
  1)
    log_info "启动/重启服务"
    stop_service
    sleep 1
    if start_service; then
        log_success "✅ 服务启动成功"
    else
        log_error "❌ 服务启动失败"
    fi
    ;;
    
  2)
    log_info "停止服务"
    if stop_service; then
        log_success "✅ 服务已停止"
    fi
    ;;
    
  3)
    log_info "重新构建并启动"
    if rebuild_service; then
        if start_service; then
            log_success "✅ 重新构建并启动成功"
        else
            log_error "❌ 构建成功但启动失败"
        fi
    else
        log_error "❌ 重新构建失败"
    fi
    ;;
    
  *)
    log_error "无效选择"
    ;;
esac

# 显示状态
echo ""
log_info "当前状态:"
if check_service; then
    echo -e "${GREEN}✅ 服务运行中 (端口: 8317)${NC}"
else
    echo -e "${RED}❌ 服务未运行${NC}"
fi

echo ""
log_info "目录结构 ($CLI_DIR):"
ls -la "$CLI_DIR" 2>/dev/null