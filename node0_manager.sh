#!/bin/bash
# Node0 Manager - Простая версия
# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Пути
NODE0_DIR="$HOME/node0"
CONDA_ENV="node0"
CONDA_HOME="$HOME/miniconda3"
CONFIG_FILE="$HOME/.node0_config"

# Функции вывода
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Установка всего необходимого и Node0
install_node0() {
    clear
    echo -e "${YELLOW}=== УСТАНОВКА NODE0 ===${NC}\n"
    
    # 1. Системные пакеты
    log "Устанавливаем системные пакеты..."
    if command -v sudo &> /dev/null; then
        sudo apt update
        sudo apt install -y git curl wget python3-pip tmux lsof build-essential
    else
        apt update
        apt install -y git curl wget python3-pip tmux lsof build-essential
    fi
    
    # 2. Conda
    if [ ! -f "$CONDA_HOME/bin/conda" ]; then
        log "Устанавливаем Conda..."
        mkdir -p ~/miniconda3
        wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
        bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
        rm ~/miniconda3/miniconda.sh
        "$CONDA_HOME/bin/conda" init bash
        source ~/.bashrc
    fi
    
    # Инициализируем conda
    eval "$($CONDA_HOME/bin/conda shell.bash hook)"
    
    # 3. Клонируем репозиторий
    if [ -d "$NODE0_DIR" ]; then
        warning "Node0 уже установлена"
        read -p "Переустановить? (y/n): " reinstall
        if [ "$reinstall" != "y" ]; then
            return
        fi
        # Сохраняем ключ
        [ -f "$NODE0_DIR/private.key" ] && cp "$NODE0_DIR/private.key" ~/private.key.backup
        rm -rf "$NODE0_DIR"
    fi
    
    log "Клонируем репозиторий..."
    git clone https://github.com/PluralisResearch/node0 "$NODE0_DIR"
    cd "$NODE0_DIR"
    
    # Восстанавливаем ключ
    [ -f ~/private.key.backup ] && cp ~/private.key.backup private.key
    
    # 4. Создаем окружение с Python 3.11
    log "Создаем окружение Python 3.11..."
    # Удаляем старое окружение если есть
    conda env remove -n "$CONDA_ENV" -y 2>/dev/null || true
    
    # Создаем новое окружение с Python 3.11.9
    conda create -n "$CONDA_ENV" python=3.11.9 -y
    
    # Активируем окружение
    source $CONDA_HOME/etc/profile.d/conda.sh
    conda activate "$CONDA_ENV"
    
    # Проверяем что окружение активно
    if [ "$CONDA_DEFAULT_ENV" != "$CONDA_ENV" ]; then
        error "Не удалось активировать окружение!"
        return
    fi
    
    log "Окружение активировано: $CONDA_DEFAULT_ENV"
    log "Python путь: $(which python)"
    log "Python версия: $(python --version)"
    
    # ВАЖНО: все последующие pip install будут в это окружение
    
    # 5. Устанавливаем Node0
    log "Устанавливаем Node0..."
    # Убеждаемся что мы в правильном окружении
    which python
    python --version
    
    # Обновляем pip В ОКРУЖЕНИИ
    python -m pip install --upgrade pip
    
    # Устанавливаем Node0 В ОКРУЖЕНИЕ
    python -m pip install .
    
    # Проверяем что установилось
    log "Проверка установки..."
    python -c "import node0; print('Node0 установлена успешно')" 2>/dev/null || warning "Проверка импорта не прошла"
    
    # 6. Настройка
    echo -e "\n${BLUE}=== НАСТРОЙКА ===${NC}"
    
    # Загружаем сохраненные данные
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo "Использовать сохраненные данные? (y/n)"
        echo "Email: ${SAVED_EMAIL:-не задан}"
        read -p "Ответ: " use_saved
        
        if [ "$use_saved" = "y" ]; then
            HF_TOKEN="$SAVED_TOKEN"
            EMAIL_ADDRESS="$SAVED_EMAIL"
            ANNOUNCE_PORT="$SAVED_ANNOUNCE_PORT"
        else
            HF_TOKEN=""
        fi
    fi
    
    # Запрашиваем данные если нужно
    if [ -z "$HF_TOKEN" ]; then
        echo ""
        echo "Получите токен: https://huggingface.co/settings/tokens"
        read -p "HuggingFace токен: " HF_TOKEN
        read -p "Email: " EMAIL_ADDRESS
        read -p "Announce port (Enter пропустить): " ANNOUNCE_PORT
        
        # Сохраняем
        cat > "$CONFIG_FILE" << EOF
SAVED_TOKEN='$HF_TOKEN'
SAVED_EMAIL='$EMAIL_ADDRESS'
SAVED_ANNOUNCE_PORT='$ANNOUNCE_PORT'
EOF
    fi
    
    # 7. Генерируем скрипты
    log "Генерируем скрипты запуска..."
    # Убеждаемся что мы все еще в окружении
    if [ "$CONDA_DEFAULT_ENV" != "$CONDA_ENV" ]; then
        conda activate "$CONDA_ENV"
    fi
    
    if [ -z "$ANNOUNCE_PORT" ]; then
        python generate_script.py --host_port 49200 --token "$HF_TOKEN" --email "$EMAIL_ADDRESS" <<< "n"
    else
        python generate_script.py --host_port 49200 --announce_port "$ANNOUNCE_PORT" --token "$HF_TOKEN" --email "$EMAIL_ADDRESS" <<< "n"
    fi
    
    # Исправляем start_server.sh
    sed -i 's/python3\.11/python/g' start_server.sh 2>/dev/null || true
    sed -i 's/python3/python/g' start_server.sh 2>/dev/null || true
    chmod +x start_server.sh
    
    echo -e "\n${GREEN}✅ Node0 установлена!${NC}"
    echo -e "${YELLOW}Используйте пункт 2 для запуска${NC}"
    read -p "Enter..."
}

# Запуск с автоматической регистрацией
start_node0() {
    clear
    echo -e "${YELLOW}=== ЗАПУСК NODE0 ===${NC}\n"
    
    if [ ! -d "$NODE0_DIR" ]; then
        error "Node0 не установлена! Сначала выполните установку."
        read -p "Enter..."
        return
    fi
    
    cd "$NODE0_DIR"
    
    # Останавливаем старые процессы
    log "Очистка..."
    tmux kill-session -t node0 2>/dev/null || true
    rm -f /tmp/hivemind* 2>/dev/null || true
    for pid in $(lsof -t -i tcp:49200 2>/dev/null); do
        kill -9 $pid 2>/dev/null || true
    done
    
    # Создаем скрипт автозапуска
    cat > auto_start.sh << 'EOF'
#!/bin/bash
# Инициализация conda
export PATH="$HOME/miniconda3/bin:$PATH"
source $HOME/miniconda3/etc/profile.d/conda.sh
conda activate node0

echo "Python: $(which python)"
echo "Версия: $(python --version)"

# Запуск с повторными попытками
attempt=0
while [ $attempt -lt 1000 ]; do
    attempt=$((attempt + 1))
    echo "[$(date '+%H:%M:%S')] Попытка #$attempt"
    
    # Очистка
    rm -f /tmp/hivemind* 2>/dev/null
    for pid in $(lsof -t -i tcp:49200 2>/dev/null); do
        kill -9 $pid 2>/dev/null
    done
    
    # Запуск
    ./start_server.sh
    
    # Если упало - ждем и пробуем снова
    echo "Процесс завершился. Повтор через 30 секунд..."
    sleep 30
done
EOF
    chmod +x auto_start.sh
    
    # Запускаем в tmux
    log "Запускаем Node0..."
    tmux new-session -d -s node0 "./auto_start.sh"
    
    sleep 3
    
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "${GREEN}✅ Node0 запущена!${NC}"
        echo ""
        echo "Команды:"
        echo -e "  Смотреть логи: ${YELLOW}tmux attach -t node0${NC}"
        echo -e "  Выйти из логов: ${YELLOW}Ctrl+B, затем D${NC}"
        echo ""
        echo -e "${GREEN}Dashboard: https://dashboard.pluralis.ai/${NC}"
    else
        error "Не удалось запустить!"
    fi
    
    read -p "Enter..."
}

# Остановка
stop_node0() {
    log "Останавливаем Node0..."
    tmux kill-session -t node0 2>/dev/null || true
    rm -f /tmp/hivemind* 2>/dev/null || true
    for pid in $(lsof -t -i tcp:49200 2>/dev/null); do
        kill -9 $pid 2>/dev/null || true
    done
    pkill -f "start_server.sh" 2>/dev/null || true
    pkill -f "auto_start.sh" 2>/dev/null || true
    echo -e "${GREEN}✅ Остановлено${NC}"
}

# Удаление
remove_node0() {
    clear
    echo -e "${RED}=== УДАЛЕНИЕ NODE0 ===${NC}\n"
    read -p "Удалить Node0? Введите YES: " confirm
    
    if [ "$confirm" = "YES" ]; then
        stop_node0
        
        # Сохраняем ключ
        [ -f "$NODE0_DIR/private.key" ] && cp "$NODE0_DIR/private.key" ~/private.key.backup && \
            log "private.key сохранен в ~/private.key.backup"
        
        # Удаляем
        rm -rf "$NODE0_DIR"
        
        # Удаляем conda окружение
        eval "$($CONDA_HOME/bin/conda shell.bash hook)"
        conda remove -n "$CONDA_ENV" --all -y 2>/dev/null || true
        
        read -p "Удалить сохраненную конфигурацию? (y/n): " del_config
        [ "$del_config" = "y" ] && rm -f "$CONFIG_FILE"
        
        echo -e "${GREEN}✅ Удалено${NC}"
    fi
    read -p "Enter..."
}

# Просмотр логов
view_logs() {
    if tmux has-session -t node0 2>/dev/null; then
        tmux attach -t node0
    else
        error "Node0 не запущена!"
        read -p "Enter..."
    fi
}

# Проверка статуса
check_status() {
    echo -n "Статус: "
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "${GREEN}🟢 Работает${NC}"
    else
        echo -e "${RED}🔴 Остановлена${NC}"
    fi
    
    # Проверяем окружение
    if [ -f "$CONDA_HOME/bin/conda" ]; then
        eval "$($CONDA_HOME/bin/conda shell.bash hook)"
        if conda env list | grep -q "$CONDA_ENV"; then
            echo -e "Окружение: ${GREEN}$CONDA_ENV (Python 3.11)${NC}"
        else
            echo -e "Окружение: ${YELLOW}Не создано${NC}"
        fi
    fi
    
    if [ -d "$NODE0_DIR" ]; then
        if [ -f "$NODE0_DIR/private.key" ]; then
            echo -e "Private key: ${GREEN}✓${NC}"
        else
            echo -e "Private key: ${YELLOW}Будет создан при запуске${NC}"
        fi
    fi
    echo ""
}

# Главное меню
while true; do
    clear
    echo -e "${BLUE}═══════════════════════════════${NC}"
    echo -e "${BLUE}     NODE0 MANAGER SIMPLE      ${NC}"
    echo -e "${BLUE}═══════════════════════════════${NC}\n"
    
    check_status
    
    echo "1) 📦 Установить Node0"
    echo "2) ▶️  Запустить (автоматическая регистрация)"
    echo "3) 📺 Смотреть логи"
    echo "4) ⏹️  Остановить"
    echo "5) 🗑️  Удалить"
    echo "0) Выход"
    echo ""
    
    read -p "Выбор: " choice
    
    case $choice in
        1) install_node0 ;;
        2) start_node0 ;;
        3) view_logs ;;
        4) 
            stop_node0
            read -p "Enter..."
            ;;
        5) remove_node0 ;;
        0) 
            echo "Пока!"
            exit 0 
            ;;
        *) 
            error "Неверный выбор!"
            sleep 1
            ;;
    esac
done
