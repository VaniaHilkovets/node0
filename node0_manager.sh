#!/bin/bash
# Node0 Minimal Manager - FIXED VERSION
# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Пути
NODE0_DIR="$HOME/node0"
CONDA_ENV="node0"
MINICONDA_DIR="$HOME/miniconda3"

# Функции логирования
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ПРАВИЛЬНАЯ установка conda
install_conda() {
    log "Устанавливаем Miniconda..."
    
    # Удаляем старую установку если есть
    [ -d "$MINICONDA_DIR" ] && rm -rf "$MINICONDA_DIR"
    
    # Скачиваем и устанавливаем
    wget -O miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    bash miniconda.sh -b -p "$MINICONDA_DIR"
    rm miniconda.sh
    
    # Инициализируем conda
    "$MINICONDA_DIR/bin/conda" init bash
    source ~/.bashrc
    
    # Добавляем в PATH для текущей сессии
    export PATH="$MINICONDA_DIR/bin:$PATH"
    
    log "Conda установлена"
}

# Установка
install_node0() {
    clear
    echo -e "${YELLOW}🚀 Установка Node0${NC}\n"
    
    # Зависимости
    log "Устанавливаем зависимости..."
    sudo apt update
    sudo apt install -y git curl wget build-essential tmux lsof python3-full
    
    # Устанавливаем ufw если нет
    if ! command -v ufw &> /dev/null; then
        sudo apt install -y ufw
    fi
    
    # Устанавливаем conda
    if ! command -v conda &> /dev/null; then
        install_conda
    fi
    
    # Убеждаемся что conda в PATH
    export PATH="$MINICONDA_DIR/bin:$PATH"
    
    # СОЗДАЕМ ОКРУЖЕНИЕ СНАЧАЛА
    log "Создаем conda окружение node0..."
    conda create -n "$CONDA_ENV" python=3.11 -y
    
    # Проверяем что создалось
    if ! conda env list | grep -q "$CONDA_ENV"; then
        error "Блядь, окружение не создалось!"
        exit 1
    fi
    
    # Клонируем репозиторий
    log "Клонируем Node0..."
    [ -d "$NODE0_DIR" ] && rm -rf "$NODE0_DIR"
    git clone https://github.com/VaniaHilkovets/node0 "$NODE0_DIR"
    cd "$NODE0_DIR"
    
    # АКТИВИРУЕМ ОКРУЖЕНИЕ И УСТАНАВЛИВАЕМ
    log "Активируем окружение и устанавливаем зависимости..."
    source "$MINICONDA_DIR/bin/activate" "$CONDA_ENV"
    
    # Устанавливаем в активированном окружении
    pip install --upgrade pip
    pip install -r requirements.txt 2>/dev/null || pip install torch torchvision transformers datasets accelerate
    pip install -e . 2>/dev/null || log "Прямая установка пакета не удалась, но это не критично"
    
    # Создаем ПРАВИЛЬНЫЙ start_server.sh
    log "Создаем start_server.sh..."
    cat > start_server.sh << 'EOF'
#!/bin/bash
echo "=== Запуск Node0 ==="

# СНАЧАЛА АКТИВИРУЕМ ОКРУЖЕНИЕ
echo "Активируем conda окружение node0..."
source ~/miniconda3/bin/activate node0

echo "Проверяем окружение:"
echo "Python: $(which python)"
echo "Version: $(python --version)"
echo "Conda env: $CONDA_DEFAULT_ENV"

# ТЕПЕРЬ ЗАПУСКАЕМ НОДУ
echo "Запускаем Node0..."
cd ~/node0

# Пробуем разные варианты запуска
if [ -f "main.py" ]; then
    python main.py
elif [ -f "server.py" ]; then
    python server.py
elif [ -f "start.py" ]; then
    python start.py
else
    echo "Ищем Python файлы для запуска:"
    find . -name "*.py" -type f | head -5
    echo "Запускаем интерактивную сессию Python"
    python
fi
EOF
    chmod +x start_server.sh
    
    # Настройка порта
    sudo ufw allow 49200/tcp 2>/dev/null
    
    # Генерация токена
    echo -e "\n${RED}Нужен токен HuggingFace: https://huggingface.co/settings/tokens${NC}"
    read -p "Enter для продолжения..."
    
    if [ -f "generate_script.py" ]; then
        python generate_script.py
    else
        log "Создаем .env файл для токена..."
        echo -n "Введите HuggingFace token: "
        read -s hf_token
        echo "HUGGINGFACE_TOKEN=$hf_token" > .env
        echo -e "\nТокен сохранен!"
    fi
    
    echo -e "\n${GREEN}✅ Установка завершена!${NC}"
    read -p "Enter..."
}

# Запуск
start_node0() {
    clear
    echo -e "${YELLOW}🚀 Запуск Node0${NC}\n"
    
    if [ ! -d "$NODE0_DIR" ]; then
        error "Node0 не установлена!"
        read -p "Enter..."
        return
    fi
    
    # Убиваем старые процессы
    tmux kill-session -t node0 2>/dev/null
    pkill -f "node0" 2>/dev/null
    sleep 2
    
    cd "$NODE0_DIR"
    
    # СОЗДАЕМ TMUX СЕССИЮ КОТОРАЯ СНАЧАЛА АКТИВИРУЕТ ОКРУЖЕНИЕ
    log "Запускаем в tmux..."
    tmux new-session -d -s node0 "bash --login -c '
        echo \"Инициализация...\"
        export PATH=\"$MINICONDA_DIR/bin:\$PATH\"
        
        echo \"Активируем окружение node0...\"
        source $MINICONDA_DIR/bin/activate node0
        
        echo \"Окружение активировано: \$CONDA_DEFAULT_ENV\"
        echo \"Python: \$(which python)\"
        
        cd $NODE0_DIR
        echo \"Запускаем start_server.sh...\"
        ./start_server.sh || exec bash
    '"
    
    sleep 3
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "${GREEN}✅ Node0 запущена!${NC}"
        echo -e "${BLUE}Подключиться: tmux attach -t node0${NC}"
    else
        error "Не удалось запустить"
    fi
    
    read -p "Enter..."
}

# Подключение к сессии
attach_node0() {
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "${BLUE}Подключаемся к node0...${NC}"
        tmux attach -t node0
    else
        error "Сессия не найдена!"
        read -p "Enter..."
    fi
}

# Остановка
stop_node0() {
    clear
    log "Остановка Node0..."
    tmux kill-session -t node0 2>/dev/null
    pkill -f "node0" 2>/dev/null
    echo -e "${GREEN}✅ Остановлена${NC}"
    read -p "Enter..."
}

# Удаление
remove_node0() {
    clear
    echo -e "${RED}Удалить все? Введите 'YES':${NC} "
    read confirm
    if [ "$confirm" = "YES" ]; then
        stop_node0 >/dev/null
        [ -f "$NODE0_DIR/private.key" ] && cp "$NODE0_DIR/private.key" ~/private.key.backup
        rm -rf "$NODE0_DIR"
        conda remove -n "$CONDA_ENV" --all -y 2>/dev/null
        echo -e "${GREEN}✅ Удалено${NC}"
    fi
    read -p "Enter..."
}

# Проверка окружения
check_environment() {
    clear
    echo -e "${BLUE}🔧 Проверка окружения${NC}\n"
    
    log "Проверяем conda..."
    if command -v conda &> /dev/null; then
        echo -e "${GREEN}✅ conda найдена${NC}"
        conda --version
    else
        echo -e "${RED}❌ conda не найдена${NC}"
        export PATH="$MINICONDA_DIR/bin:$PATH"
    fi
    
    log "Список окружений:"
    conda env list
    
    if conda env list | grep -q "$CONDA_ENV"; then
        echo -e "${GREEN}✅ Окружение node0 существует${NC}"
        
        log "Тестируем окружение..."
        source "$MINICONDA_DIR/bin/activate" "$CONDA_ENV"
        echo "Python: $(which python)"
        echo "Version: $(python --version)"
        python -c "print('Python работает!')"
    else
        echo -e "${RED}❌ Окружение node0 НЕ найдено${NC}"
        log "Создаем окружение..."
        conda create -n "$CONDA_ENV" python=3.11 -y
    fi
    
    read -p "Enter..."
}

# Меню
while true; do
    clear
    echo -e "${BLUE}NODE0 MANAGER${NC}\n"
    
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "Статус: ${GREEN}🟢 Работает${NC}\n"
    else
        echo -e "Статус: ${RED}🔴 Остановлена${NC}\n"
    fi
    
    echo "1) Установить ноду"
    echo "2) Запустить ноду" 
    echo "3) Подключиться к сессии"
    echo "4) Остановить ноду"
    echo "5) Удалить ноду"
    echo "6) Проверить окружение"
    echo "0) Выход"
    
    read -p "Выбор: " choice
    
    case $choice in
        1) install_node0 ;;
        2) start_node0 ;;
        3) attach_node0 ;;
        4) stop_node0 ;;
        5) remove_node0 ;;
        6) check_environment ;;
        0) exit 0 ;;
    esac
done
