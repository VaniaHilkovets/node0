#!/bin/bash
# Node0 Manager - Простая рабочая версия
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NODE0_DIR="$HOME/node0"
CONFIG_FILE="$HOME/.node0_config"

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# УСТАНОВКА
install_node0() {
    clear
    echo -e "${YELLOW}=== УСТАНОВКА NODE0 ===${NC}\n"
    
    # Системные пакеты
    log "Устанавливаем пакеты..."
    if command -v sudo &> /dev/null; then
        sudo apt update && sudo apt install -y git curl wget python3.11 python3.11-venv python3-pip tmux
    else
        apt update && apt install -y git curl wget python3.11 python3.11-venv python3-pip tmux
    fi
    
    # Клонируем репозиторий
    if [ -d "$NODE0_DIR" ]; then
        warning "Node0 уже существует"
        read -p "Переустановить? (y/n): " r
        if [ "$r" != "y" ]; then return; fi
        [ -f "$NODE0_DIR/private.key" ] && cp "$NODE0_DIR/private.key" ~/private.key.backup
        rm -rf "$NODE0_DIR"
    fi
    
    git clone https://github.com/PluralisResearch/node0 "$NODE0_DIR"
    cd "$NODE0_DIR"
    [ -f ~/private.key.backup ] && cp ~/private.key.backup private.key
    
    # Создаем виртуальное окружение Python 3.11
    log "Создаем Python окружение..."
    python3.11 -m venv venv
    source venv/bin/activate
    
    # Устанавливаем Node0
    log "Устанавливаем Node0..."
    pip install --upgrade pip
    pip install .
    
    # Настройка
    echo -e "\n${BLUE}=== НАСТРОЙКА ===${NC}"
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo "Найдены сохраненные данные. Использовать? (y/n)"
        read -p "> " use
        if [ "$use" = "y" ]; then
            HF_TOKEN="$SAVED_TOKEN"
            EMAIL="$SAVED_EMAIL"
            PORT="$SAVED_PORT"
        else
            HF_TOKEN=""
        fi
    fi
    
    if [ -z "$HF_TOKEN" ]; then
        echo "Токен: https://huggingface.co/settings/tokens"
        read -p "HF токен: " HF_TOKEN
        read -p "Email: " EMAIL
        read -p "Announce port (Enter=пропустить): " PORT
        
        cat > "$CONFIG_FILE" << EOF
SAVED_TOKEN='$HF_TOKEN'
SAVED_EMAIL='$EMAIL'
SAVED_PORT='$PORT'
EOF
    fi
    
    # Генерируем скрипт запуска
    log "Генерируем скрипты..."
    if [ -z "$PORT" ]; then
        python generate_script.py --host_port 49200 --token "$HF_TOKEN" --email "$EMAIL" <<< "n"
    else
        python generate_script.py --host_port 49200 --announce_port "$PORT" --token "$HF_TOKEN" --email "$EMAIL" <<< "n"
    fi
    
    # Проверяем что скрипт создан
    if [ ! -f "start_server.sh" ]; then
        error "Скрипт не создан! Проверьте токен."
        deactivate
        return
    fi
    
    chmod +x start_server.sh
    deactivate
    
    echo -e "\n${GREEN}✅ Установлено!${NC}"
    read -p "Enter..."
}

# ЗАПУСК
start_node0() {
    clear
    echo -e "${YELLOW}=== ЗАПУСК NODE0 ===${NC}\n"
    
    if [ ! -d "$NODE0_DIR" ]; then
        error "Не установлено!"
        read -p "Enter..."
        return
    fi
    
    cd "$NODE0_DIR"
    
    if [ ! -f "start_server.sh" ]; then
        error "Нет скрипта запуска!"
        read -p "Enter..."
        return
    fi
    
    # Останавливаем старое
    tmux kill-session -t node0 2>/dev/null || true
    pkill -f start_server.sh 2>/dev/null || true
    
    # Создаем скрипт с циклом
    cat > run_node0.sh << 'EOF'
#!/bin/bash
cd ~/node0
source venv/bin/activate
echo "Python: $(which python)"
echo "Версия: $(python --version)"

attempt=0
while true; do
    attempt=$((attempt + 1))
    echo "[$(date '+%H:%M:%S')] Попытка #$attempt"
    
    # Очистка
    rm -f /tmp/hivemind* 2>/dev/null
    pkill -f "python.*server" 2>/dev/null || true
    sleep 2
    
    # Запуск
    ./start_server.sh
    
    echo "Перезапуск через 30 секунд..."
    sleep 30
done
EOF
    chmod +x run_node0.sh
    
    # Запускаем
    log "Запускаем..."
    tmux new-session -d -s node0 "./run_node0.sh"
    
    sleep 2
    
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "${GREEN}✅ Запущено!${NC}"
        echo ""
        echo -e "Смотреть: ${YELLOW}tmux attach -t node0${NC}"
        echo -e "Выйти: ${YELLOW}Ctrl+B, D${NC}"
        echo ""
        echo -e "${GREEN}Dashboard: https://dashboard.pluralis.ai/${NC}"
    else
        error "Ошибка запуска!"
    fi
    
    read -p "Enter..."
}

# ЛОГИ
view_logs() {
    if tmux has-session -t node0 2>/dev/null; then
        tmux attach -t node0
    else
        if [ -f "$NODE0_DIR/logs/server.log" ]; then
            tail -f "$NODE0_DIR/logs/server.log"
        else
            error "Нет логов!"
            read -p "Enter..."
        fi
    fi
}

# СТОП
stop_node0() {
    log "Останавливаем..."
    tmux kill-session -t node0 2>/dev/null || true
    pkill -f start_server.sh 2>/dev/null || true
    pkill -f run_node0.sh 2>/dev/null || true
    pkill -f "python.*server" 2>/dev/null || true
    rm -f /tmp/hivemind* 2>/dev/null || true
    echo -e "${GREEN}✅ Остановлено${NC}"
}

# УДАЛЕНИЕ
remove_node0() {
    clear
    echo -e "${RED}=== УДАЛЕНИЕ ===${NC}\n"
    read -p "Удалить? (YES): " c
    
    if [ "$c" = "YES" ]; then
        stop_node0
        [ -f "$NODE0_DIR/private.key" ] && cp "$NODE0_DIR/private.key" ~/private.key.backup
        rm -rf "$NODE0_DIR"
        rm -f "$CONFIG_FILE"
        echo -e "${GREEN}✅ Удалено${NC}"
        [ -f ~/private.key.backup ] && echo "private.key сохранен в ~/private.key.backup"
    fi
    read -p "Enter..."
}

# СТАТУС
check_status() {
    echo -n "Статус: "
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "${GREEN}🟢 Работает${NC}"
    else
        echo -e "${RED}🔴 Остановлена${NC}"
    fi
    [ -f "$NODE0_DIR/private.key" ] && echo -e "Key: ${GREEN}✓${NC}"
    echo ""
}

# МЕНЮ
while true; do
    clear
    echo -e "${BLUE}═══ NODE0 MANAGER ═══${NC}\n"
    check_status
    
    echo "1) Установить"
    echo "2) Запустить"
    echo "3) Логи"
    echo "4) Стоп"
    echo "5) Удалить"
    echo "0) Выход"
    echo ""
    
    read -p "> " choice
    
    case $choice in
        1) install_node0 ;;
        2) start_node0 ;;
        3) view_logs ;;
        4) stop_node0; read -p "Enter..." ;;
        5) remove_node0 ;;
        0) exit 0 ;;
    esac
done
