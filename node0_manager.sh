#!/bin/bash
# Node0 Pluralis Manager - Minimal
# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Пути
NODE0_DIR="$HOME/node0"
CONDA_ENV="node0"

# Функции логирования
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Установка зависимостей по официальному гайду
install_dependencies() {
    log "Устанавливаем зависимости..."
    
    # Update System Packages
    sudo apt update && sudo apt upgrade -y
    
    # Install General Utilities and Tools
    sudo apt install screen curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y
    
    # Install Python and pip
    sudo apt install -y python3-pip
    sudo apt install pip
    sudo apt install -y build-essential libssl-dev libffi-dev python3-dev
}

# Установка Conda по официальному гайду
install_conda() {
    log "Устанавливаем Conda..."
    
    mkdir -p ~/miniconda3
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
    bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
    rm ~/miniconda3/miniconda.sh
    
    source ~/miniconda3/bin/activate
    conda init --all
    
    # Перезагружаем bashrc
    source ~/.bashrc
}

# Установка Node0
install_node0() {
    clear
    echo -e "${YELLOW}🚀 Установка Node0 Pluralis${NC}\n"
    
    # Проверяем зависимости
    if ! command -v conda &> /dev/null; then
        install_dependencies
        install_conda
    fi
    
    # Убеждаемся что conda доступна
    export PATH="$HOME/miniconda3/bin:$PATH"
    source ~/.bashrc
    
    # Клонируем ОФИЦИАЛЬНЫЙ репозиторий
    log "Клонируем официальный репозиторий Pluralis..."
    [ -d "$NODE0_DIR" ] && rm -rf "$NODE0_DIR"
    git clone https://github.com/PluralisResearch/node0 "$NODE0_DIR"
    cd "$NODE0_DIR"
    
    # Создаем conda environment
    log "Создаем conda окружение node0..."
    conda create -n node0 python=3.11 -y
    
    # Активируем conda environment
    log "Активируем окружение node0..."
    conda activate node0
    
    # Устанавливаем Node0
    log "Устанавливаем Node0..."
    pip install .
    
    # ПРИНУДИТЕЛЬНО устанавливаем нужный Python
    log "Принудительно устанавливаем Python 3.11..."
    conda install python=3.11 -y
    python --version
    
    # Получаем данные от пользователя
    CONFIG_FILE="$HOME/.node0_config"
    
    echo -e "\n${BLUE}=== Настройка Node0 ===${NC}"
    
    # Загружаем сохраненные данные если есть
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo "Найдены сохраненные данные:"
        echo "Email: ${SAVED_EMAIL:-не задан}"
        echo "Token: ${SAVED_TOKEN:0:10}... (скрыт)"
        echo "Announce port: ${SAVED_ANNOUNCE_PORT:-не задан}"
        echo ""
        read -p "Использовать сохраненные данные? (y/n): " use_saved
        if [ "$use_saved" = "y" ] || [ "$use_saved" = "Y" ]; then
            HF_TOKEN="$SAVED_TOKEN"
            EMAIL_ADDRESS="$SAVED_EMAIL"
            ANNOUNCE_PORT="$SAVED_ANNOUNCE_PORT"
        fi
    fi
    
    # Если не используем сохраненные или их нет - спрашиваем
    if [ -z "$HF_TOKEN" ]; then
        echo "1. HuggingFace токен: https://huggingface.co/settings/tokens"
        echo "2. Email адрес"
        echo "3. Announce port (если Vast - проверьте в панели, иначе Enter)"
        echo ""
        
        read -p "HuggingFace токен: " HF_TOKEN
        read -p "Email адрес: " EMAIL_ADDRESS
        read -p "Announce port (Enter для пропуска): " ANNOUNCE_PORT
        
        # Сохраняем данные
        echo "SAVED_TOKEN='$HF_TOKEN'" > "$CONFIG_FILE"
        echo "SAVED_EMAIL='$EMAIL_ADDRESS'" >> "$CONFIG_FILE"
        echo "SAVED_ANNOUNCE_PORT='$ANNOUNCE_PORT'" >> "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"  # Только для владельца
        log "Данные сохранены в $CONFIG_FILE"
    fi
    
    # Генерируем start_server.sh
    log "Генерируем конфигурацию..."
    if [ -z "$ANNOUNCE_PORT" ]; then
        python3 generate_script.py --host_port 49200 --token "$HF_TOKEN" --email "$EMAIL_ADDRESS"
    else
        python3 generate_script.py --host_port 49200 --announce_port "$ANNOUNCE_PORT" --token "$HF_TOKEN" --email "$EMAIL_ADDRESS"
    fi
    
    # ПРИНУДИТЕЛЬНО ИСПРАВЛЯЕМ start_server.sh
    log "Исправляем start_server.sh для правильной работы с conda..."
    if [ -f "start_server.sh" ]; then
        # Создаем резервную копию
        cp start_server.sh start_server.sh.backup
        
        # Заменяем все упоминания python3.11 на python
        sed -i 's/python3\.11/python/g' start_server.sh
        sed -i 's/python3/python/g' start_server.sh
        
        # Добавляем активацию conda в начало файла если её нет
        if ! grep -q "conda activate" start_server.sh; then
            # Создаем новый start_server.sh с правильной активацией
            cat > start_server.sh << 'EOF'
#!/bin/bash
set -e
echo "=== Запуск Node0 Pluralis ==="
source ~/miniconda3/bin/activate node0
echo "Python version: $(python --version)"
echo "Python path: $(which python)"
EOF
            # Добавляем оригинальное содержимое без первых строк активации
            tail -n +4 start_server.sh.backup >> start_server.sh
            chmod +x start_server.sh
        fi
        
        log "start_server.sh исправлен"
    else
        error "start_server.sh не создан!"
    fi
    
    echo -e "\n${GREEN}✅ Node0 установлена!${NC}"
    read -p "Enter..."
}

# Запуск в tmux
start_node0() {
    clear
    echo -e "${YELLOW}🚀 Запуск Node0${NC}\n"
    
    if [ ! -d "$NODE0_DIR" ]; then
        error "Node0 не установлена! Установите сначала."
        read -p "Enter..."
        return
    fi
    
    cd "$NODE0_DIR"
    
    if [ ! -f "start_server.sh" ]; then
        error "start_server.sh не найден! Переустановите Node0."
        read -p "Enter..."
        return
    fi
    
    # Убиваем старую tmux сессию и очищаем порты
    tmux kill-session -t node0 2>/dev/null
    rm -f /tmp/hivemind* 2>/dev/null
    if command -v lsof &> /dev/null; then
        for i in $(sudo lsof -t -i tcp:49200 2>/dev/null); do 
            sudo kill -9 $i 2>/dev/null
        done
    fi
    
    log "Запускаем в tmux сессии 'node0'..."
    tmux new-session -d -s node0 "bash -c '
        cd $NODE0_DIR
        conda activate node0
        ./start_server.sh
    '"
    
    sleep 3
    echo -e "${GREEN}✅ Node0 запущена!${NC}"
    echo -e "${BLUE}Подключиться: tmux attach -t node0${NC}"
    echo -e "${BLUE}Выйти: Ctrl+B, затем D${NC}"
    read -p "Enter..."
}

# Подключение к tmux
connect_tmux() {
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "${BLUE}Подключаемся к tmux сессии node0...${NC}"
        echo -e "${YELLOW}Для выхода: Ctrl+B, затем D${NC}"
        sleep 2
        tmux attach -t node0
    else
        error "Tmux сессия 'node0' не найдена!"
        echo -e "${YELLOW}Сначала запустите Node0${NC}"
        read -p "Enter..."
    fi
}

# Обновление Node0
update_node0() {
    clear
    echo -e "${YELLOW}🔄 Обновление Node0${NC}\n"
    
    if [ ! -d "$NODE0_DIR" ]; then
        error "Node0 не установлена!"
        read -p "Enter..."
        return
    fi
    
    cd "$NODE0_DIR"
    
    log "Останавливаем Node0..."
    tmux kill-session -t node0 2>/dev/null
    rm -f /tmp/hivemind* 2>/dev/null
    if command -v lsof &> /dev/null; then
        for i in $(sudo lsof -t -i tcp:49200 2>/dev/null); do 
            sudo kill -9 $i 2>/dev/null
        done
    fi
    
    log "Обновляем код..."
    git pull
    
    log "Переустанавливаем пакет..."
    conda activate node0
    
    # ПРИНУДИТЕЛЬНО устанавливаем правильный Python
    conda install python=3.11 -y
    
    pip install .
    
    # ИСПРАВЛЯЕМ start_server.sh после обновления
    if [ -f "start_server.sh" ]; then
        log "Исправляем start_server.sh..."
        cp start_server.sh start_server.sh.backup
        sed -i 's/python3\.11/python/g' start_server.sh
        sed -i 's/python3/python/g' start_server.sh
        
        # Проверяем что активация conda есть
        if ! grep -q "conda activate" start_server.sh; then
            sed -i '1a source ~/miniconda3/bin/activate node0' start_server.sh
        fi
    fi
    
    echo -e "${GREEN}✅ Node0 обновлена!${NC}"
    read -p "Enter..."
}

# Удаление
remove_node0() {
    clear
    echo -e "${RED}⚠️  УДАЛЕНИЕ NODE0${NC}\n"
    echo -e "${YELLOW}Это удалит все файлы Node0${NC}"
    echo -e "${GREEN}private.key будет сохранен как ~/private.key.backup${NC}"
    echo ""
    echo -e "${RED}Введите 'YES' для подтверждения:${NC} "
    read confirm
    
    if [ "$confirm" = "YES" ]; then
        log "Останавливаем процессы..."
        tmux kill-session -t node0 2>/dev/null
        rm -f /tmp/hivemind* 2>/dev/null
        if command -v lsof &> /dev/null; then
            for i in $(sudo lsof -t -i tcp:49200 2>/dev/null); do 
                sudo kill -9 $i 2>/dev/null
            done
        fi
        
        if [ -f "$NODE0_DIR/private.key" ]; then
            log "Сохраняем private.key..."
            cp "$NODE0_DIR/private.key" ~/private.key.backup
        fi
        
        log "Удаляем файлы..."
        rm -rf "$NODE0_DIR"
        
        log "Удаляем conda окружение..."
        conda remove -n node0 --all -y 2>/dev/null
        
        echo -e "${GREEN}✅ Node0 удалена${NC}"
    else
        echo -e "${YELLOW}Удаление отменено${NC}"
    fi
    read -p "Enter..."
}

# Главное меню
while true; do
    clear
    echo -e "${BLUE}╔═══════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       NODE0 PLURALIS MANAGER      ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════╝${NC}\n"
    
    # Статус
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "Статус: ${GREEN}🟢 Работает${NC}"
    else
        echo -e "Статус: ${RED}🔴 Остановлена${NC}"
    fi
    
    if [ -d "$NODE0_DIR" ]; then
        echo -e "Установка: ${GREEN}✅ Готова${NC}\n"
    else
        echo -e "Установка: ${RED}❌ Требуется${NC}\n"
    fi
    
    echo "1) Установить"
    echo "2) Запустить"
    echo "3) Подключиться"
    echo "4) Обновить"
    echo "5) Удалить"
    echo "0) Выход"
    echo ""
    
    read -p "Выбор: " choice
    
    case $choice in
        1) install_node0 ;;
        2) start_node0 ;;
        3) connect_tmux ;;
        4) update_node0 ;;
        5) remove_node0 ;;
        0) exit 0 ;;
        *) 
            error "Неверный выбор"
            sleep 1
            ;;
    esac
done
