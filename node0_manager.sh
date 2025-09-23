#!/bin/bash
# Node0 Pluralis Manager - Fixed Version
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

# Функции логирования
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Проверка и инициализация conda
init_conda() {
    if [ -f "$CONDA_HOME/bin/conda" ]; then
        eval "$($CONDA_HOME/bin/conda shell.bash hook)"
        return 0
    fi
    return 1
}

# Установка зависимостей
install_dependencies() {
    log "Устанавливаем системные зависимости..."
    
    # Проверяем есть ли sudo
    if command -v sudo &> /dev/null; then
        sudo apt update && sudo apt upgrade -y
        sudo apt install -y screen curl iptables build-essential git wget lz4 jq make gcc nano \
            automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev \
            tar clang bsdmainutils ncdu unzip python3-pip python3-dev
    else
        # Без sudo (для некоторых VPS)
        apt update && apt upgrade -y
        apt install -y screen curl iptables build-essential git wget lz4 jq make gcc nano \
            automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev \
            tar clang bsdmainutils ncdu unzip python3-pip python3-dev
    fi
}

# Установка Conda
install_conda() {
    if [ -f "$CONDA_HOME/bin/conda" ]; then
        log "Conda уже установлена"
        return 0
    fi
    
    log "Устанавливаем Miniconda..."
    
    mkdir -p ~/miniconda3
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
    bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
    rm ~/miniconda3/miniconda.sh
    
    # Инициализируем conda
    "$CONDA_HOME/bin/conda" init bash
    
    log "Conda установлена. Перезагружаем shell..."
    source ~/.bashrc
}

# Создание правильного скрипта запуска
create_start_script() {
    local hf_token="$1"
    local email="$2"
    local announce_port="$3"
    
    cd "$NODE0_DIR"
    
    # Активируем conda для генерации
    init_conda
    conda activate "$CONDA_ENV"
    
    # Генерируем скрипт
    if [ -z "$announce_port" ]; then
        python generate_script.py --host_port 49200 --token "$hf_token" --email "$email" <<< "n"
    else
        python generate_script.py --host_port 49200 --announce_port "$announce_port" --token "$hf_token" --email "$email" <<< "n"
    fi
    
    # Создаем wrapper для правильного запуска
    cat > start_node0_wrapper.sh << 'EOF'
#!/bin/bash
set -e

# Инициализация conda
export PATH="$HOME/miniconda3/bin:$PATH"
eval "$($HOME/miniconda3/bin/conda shell.bash hook)"

# Активируем окружение
conda activate node0

# Проверка
echo "=== Проверка окружения ==="
echo "Python: $(which python)"
echo "Version: $(python --version)"
echo "Conda env: $CONDA_DEFAULT_ENV"
echo "=========================="

# Запускаем оригинальный скрипт
./start_server.sh
EOF
    
    chmod +x start_node0_wrapper.sh
    
    # Исправляем оригинальный start_server.sh
    if [ -f "start_server.sh" ]; then
        sed -i 's/python3\.11/python/g' start_server.sh
        sed -i 's/python3/python/g' start_server.sh
        chmod +x start_server.sh
    fi
}

# Установка Node0
install_node0() {
    clear
    echo -e "${YELLOW}🚀 Установка Node0 Pluralis${NC}\n"
    
    # 1. Проверяем и устанавливаем зависимости
    if ! command -v git &> /dev/null; then
        install_dependencies
    fi
    
    # 2. Проверяем и устанавливаем Conda
    if [ ! -f "$CONDA_HOME/bin/conda" ]; then
        install_conda
    fi
    
    # 3. Инициализируем conda для текущей сессии
    init_conda
    
    # 4. Клонируем репозиторий
    log "Клонируем официальный репозиторий..."
    if [ -d "$NODE0_DIR" ]; then
        warning "Директория $NODE0_DIR уже существует"
        read -p "Удалить и переустановить? (y/n): " reinstall
        if [ "$reinstall" = "y" ] || [ "$reinstall" = "Y" ]; then
            # Сохраняем private.key если есть
            if [ -f "$NODE0_DIR/private.key" ]; then
                cp "$NODE0_DIR/private.key" ~/private.key.backup
                log "private.key сохранен в ~/private.key.backup"
            fi
            rm -rf "$NODE0_DIR"
        else
            log "Установка отменена"
            read -p "Enter..."
            return
        fi
    fi
    
    git clone https://github.com/PluralisResearch/node0 "$NODE0_DIR"
    cd "$NODE0_DIR"
    
    # 5. Создаем conda окружение
    log "Создаем conda окружение с Python 3.11..."
    conda create -n "$CONDA_ENV" python=3.11 -y
    
    # 6. Активируем окружение
    conda activate "$CONDA_ENV"
    
    # 7. Проверяем Python
    log "Проверка Python..."
    python_version=$(python --version 2>&1)
    echo "Python версия: $python_version"
    
    if ! echo "$python_version" | grep -q "3.11"; then
        error "Неправильная версия Python!"
        conda install python=3.11 -y
    fi
    
    # 8. Устанавливаем Node0
    log "Устанавливаем Node0..."
    pip install --upgrade pip
    pip install .
    
    # 9. Восстанавливаем private.key если был
    if [ -f ~/private.key.backup ]; then
        cp ~/private.key.backup "$NODE0_DIR/private.key"
        log "private.key восстановлен"
    fi
    
    # 10. Настройка
    echo -e "\n${BLUE}=== Настройка Node0 ===${NC}"
    
    # Загружаем сохраненные данные
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
        else
            HF_TOKEN=""
            EMAIL_ADDRESS=""
            ANNOUNCE_PORT=""
        fi
    fi
    
    # Запрашиваем данные если нужно
    if [ -z "$HF_TOKEN" ]; then
        echo ""
        echo "Требуется настройка:"
        echo "1. HuggingFace токен: https://huggingface.co/settings/tokens"
        echo "2. Email адрес для отслеживания в dashboard"
        echo "3. Announce port (только для Vast, иначе пропустите)"
        echo ""
        
        read -p "HuggingFace токен: " HF_TOKEN
        while [ -z "$HF_TOKEN" ]; do
            error "Токен обязателен!"
            read -p "HuggingFace токен: " HF_TOKEN
        done
        
        read -p "Email адрес: " EMAIL_ADDRESS
        while [ -z "$EMAIL_ADDRESS" ]; do
            error "Email обязателен!"
            read -p "Email адрес: " EMAIL_ADDRESS
        done
        
        read -p "Announce port (Enter для пропуска): " ANNOUNCE_PORT
        
        # Сохраняем данные
        cat > "$CONFIG_FILE" << EOF
SAVED_TOKEN='$HF_TOKEN'
SAVED_EMAIL='$EMAIL_ADDRESS'
SAVED_ANNOUNCE_PORT='$ANNOUNCE_PORT'
EOF
        chmod 600 "$CONFIG_FILE"
        log "Конфигурация сохранена"
    fi
    
    # 11. Создаем скрипт запуска
    log "Генерируем скрипты запуска..."
    create_start_script "$HF_TOKEN" "$EMAIL_ADDRESS" "$ANNOUNCE_PORT"
    
    echo -e "\n${GREEN}✅ Node0 успешно установлена!${NC}"
    echo -e "${YELLOW}Используйте пункт 2 для запуска${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# Запуск Node0
start_node0() {
    clear
    echo -e "${YELLOW}🚀 Запуск Node0${NC}\n"
    
    if [ ! -d "$NODE0_DIR" ]; then
        error "Node0 не установлена! Сначала выполните установку."
        read -p "Enter..."
        return
    fi
    
    cd "$NODE0_DIR"
    
    if [ ! -f "start_node0_wrapper.sh" ] && [ ! -f "start_server.sh" ]; then
        error "Скрипты запуска не найдены! Переустановите Node0."
        read -p "Enter..."
        return
    fi
    
    # Очистка перед запуском
    log "Очистка старых процессов..."
    tmux kill-session -t node0 2>/dev/null || true
    rm -f /tmp/hivemind* 2>/dev/null || true
    
    # Убиваем процессы на порту
    if command -v lsof &> /dev/null; then
        for pid in $(lsof -t -i tcp:49200 2>/dev/null); do
            kill -9 $pid 2>/dev/null || true
        done
    fi
    
    # Запускаем в tmux
    log "Запускаем Node0 в tmux сессии..."
    
    # Используем wrapper если есть, иначе оригинальный скрипт
    if [ -f "start_node0_wrapper.sh" ]; then
        tmux new-session -d -s node0 "cd $NODE0_DIR && ./start_node0_wrapper.sh"
    else
        tmux new-session -d -s node0 "cd $NODE0_DIR && bash -c 'source $CONDA_HOME/bin/activate && conda activate $CONDA_ENV && ./start_server.sh'"
    fi
    
    sleep 3
    
    # Проверяем запустилась ли
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "${GREEN}✅ Node0 запущена успешно!${NC}\n"
        echo -e "${BLUE}Команды управления:${NC}"
        echo -e "  Подключиться к логам: ${YELLOW}tmux attach -t node0${NC}"
        echo -e "  Отключиться от логов: ${YELLOW}Ctrl+B, затем D${NC}"
        echo -e "  Посмотреть логи: ${YELLOW}tail -f $NODE0_DIR/logs/server.log${NC}"
        echo ""
        echo -e "${GREEN}Dashboard: https://dashboard.pluralis.ai/${NC}"
    else
        error "Не удалось запустить Node0!"
        echo "Проверьте логи для деталей"
    fi
    
    read -p "Нажмите Enter для продолжения..."
}

# Остановка Node0
stop_node0() {
    log "Останавливаем Node0..."
    
    # Останавливаем tmux сессию
    tmux kill-session -t node0 2>/dev/null || true
    
    # Очищаем временные файлы
    rm -f /tmp/hivemind* 2>/dev/null || true
    
    # Убиваем процессы на порту
    if command -v lsof &> /dev/null; then
        for pid in $(lsof -t -i tcp:49200 2>/dev/null); do
            kill -9 $pid 2>/dev/null || true
        done
    fi
    
    log "Node0 остановлена"
}

# Подключение к tmux
connect_tmux() {
    clear
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "${BLUE}Подключаемся к Node0...${NC}"
        echo -e "${YELLOW}Для выхода используйте: Ctrl+B, затем D${NC}"
        sleep 2
        tmux attach -t node0
    else
        error "Node0 не запущена!"
        echo -e "${YELLOW}Сначала запустите Node0 (пункт 2)${NC}"
        read -p "Enter..."
    fi
}

# Просмотр логов
view_logs() {
    clear
    echo -e "${BLUE}=== Логи Node0 ===${NC}\n"
    
    if [ ! -d "$NODE0_DIR" ]; then
        error "Node0 не установлена!"
        read -p "Enter..."
        return
    fi
    
    echo "1) Последние 50 строк"
    echo "2) Следить за логами в реальном времени"
    echo "3) Полный лог"
    echo "0) Назад"
    echo ""
    read -p "Выбор: " log_choice
    
    case $log_choice in
        1)
            if [ -f "$NODE0_DIR/logs/server.log" ]; then
                tail -n 50 "$NODE0_DIR/logs/server.log"
            else
                echo "Лог-файл не найден"
            fi
            read -p "Enter..."
            ;;
        2)
            if [ -f "$NODE0_DIR/logs/server.log" ]; then
                echo -e "${YELLOW}Для выхода нажмите Ctrl+C${NC}"
                sleep 2
                tail -f "$NODE0_DIR/logs/server.log"
            else
                echo "Лог-файл не найден"
                read -p "Enter..."
            fi
            ;;
        3)
            if [ -f "$NODE0_DIR/logs/server.log" ]; then
                less "$NODE0_DIR/logs/server.log"
            else
                echo "Лог-файл не найден"
                read -p "Enter..."
            fi
            ;;
        *)
            ;;
    esac
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
    
    # Останавливаем если работает
    stop_node0
    
    cd "$NODE0_DIR"
    
    # Сохраняем важные файлы
    if [ -f "private.key" ]; then
        cp private.key ~/private.key.backup
        log "private.key сохранен"
    fi
    
    # Обновляем репозиторий
    log "Обновляем код из репозитория..."
    git stash 2>/dev/null || true
    git pull
    
    # Активируем окружение и обновляем
    init_conda
    conda activate "$CONDA_ENV"
    
    log "Обновляем пакеты Python..."
    pip install --upgrade pip
    pip install --upgrade .
    
    # Восстанавливаем private.key
    if [ -f ~/private.key.backup ]; then
        cp ~/private.key.backup private.key
    fi
    
    # Перегенерируем скрипты запуска
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        create_start_script "$SAVED_TOKEN" "$SAVED_EMAIL" "$SAVED_ANNOUNCE_PORT"
    fi
    
    echo -e "${GREEN}✅ Node0 успешно обновлена!${NC}"
    read -p "Enter..."
}

# Удаление Node0
remove_node0() {
    clear
    echo -e "${RED}⚠️  УДАЛЕНИЕ NODE0${NC}\n"
    echo -e "${YELLOW}Это действие удалит:${NC}"
    echo "  - Все файлы Node0"
    echo "  - Conda окружение"
    echo "  - Конфигурацию"
    echo ""
    echo -e "${GREEN}Будет сохранено:${NC}"
    echo "  - private.key -> ~/private.key.backup"
    echo ""
    echo -e "${RED}Введите 'YES' для подтверждения:${NC} "
    read confirm
    
    if [ "$confirm" = "YES" ]; then
        # Останавливаем
        stop_node0
        
        # Сохраняем private.key
        if [ -f "$NODE0_DIR/private.key" ]; then
            cp "$NODE0_DIR/private.key" ~/private.key.backup
            log "private.key сохранен в ~/private.key.backup"
        fi
        
        # Удаляем директорию
        log "Удаляем файлы..."
        rm -rf "$NODE0_DIR"
        
        # Удаляем conda окружение
        if init_conda; then
            log "Удаляем conda окружение..."
            conda remove -n "$CONDA_ENV" --all -y 2>/dev/null || true
        fi
        
        # Спрашиваем про конфигурацию
        read -p "Удалить сохраненную конфигурацию? (y/n): " del_config
        if [ "$del_config" = "y" ] || [ "$del_config" = "Y" ]; then
            rm -f "$CONFIG_FILE"
        fi
        
        echo -e "${GREEN}✅ Node0 удалена${NC}"
    else
        echo -e "${YELLOW}Удаление отменено${NC}"
    fi
    read -p "Enter..."
}

# Проверка статуса
check_status() {
    echo -e "${BLUE}=== Статус системы ===${NC}\n"
    
    # Node0 установлена?
    if [ -d "$NODE0_DIR" ]; then
        echo -e "Node0: ${GREEN}Установлена${NC}"
        
        # Проверяем private.key
        if [ -f "$NODE0_DIR/private.key" ]; then
            echo -e "Private key: ${GREEN}Найден${NC}"
        else
            echo -e "Private key: ${YELLOW}Отсутствует${NC}"
        fi
    else
        echo -e "Node0: ${RED}Не установлена${NC}"
    fi
    
    # Conda
    if [ -f "$CONDA_HOME/bin/conda" ]; then
        echo -e "Conda: ${GREEN}Установлена${NC}"
        
        # Проверяем окружение
        if init_conda && conda env list | grep -q "$CONDA_ENV"; then
            echo -e "Окружение $CONDA_ENV: ${GREEN}Создано${NC}"
        else
            echo -e "Окружение $CONDA_ENV: ${RED}Не найдено${NC}"
        fi
    else
        echo -e "Conda: ${RED}Не установлена${NC}"
    fi
    
    # Tmux сессия
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "Процесс: ${GREEN}🟢 Работает${NC}"
    else
        echo -e "Процесс: ${RED}🔴 Остановлен${NC}"
    fi
    
    # Конфигурация
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "Конфигурация: ${GREEN}Сохранена${NC}"
    else
        echo -e "Конфигурация: ${YELLOW}Не найдена${NC}"
    fi
    
    echo ""
}

# Главное меню
while true; do
    clear
    echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       NODE0 PLURALIS MANAGER v2       ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}\n"
    
    check_status
    
    echo -e "${YELLOW}Основные действия:${NC}"
    echo "  1) 📦 Установить Node0"
    echo "  2) ▶️  Запустить Node0"
    echo "  3) 📺 Подключиться к консоли"
    echo "  4) 📄 Просмотр логов"
    echo ""
    echo -e "${BLUE}Управление:${NC}"
    echo "  5) 🔄 Обновить Node0"
    echo "  6) ⏹️  Остановить Node0"
    echo "  7) 🗑️  Удалить Node0"
    echo ""
    echo "  0) Выход"
    echo ""
    
    read -p "Выберите действие: " choice
    
    case $choice in
        1) install_node0 ;;
        2) start_node0 ;;
        3) connect_tmux ;;
        4) view_logs ;;
        5) update_node0 ;;
        6) 
            stop_node0
            echo -e "${GREEN}Node0 остановлена${NC}"
            read -p "Enter..."
            ;;
        7) remove_node0 ;;
        0) 
            echo -e "${GREEN}До свидания!${NC}"
            exit 0 
            ;;
        *) 
            error "Неверный выбор!"
            sleep 1
            ;;
    esac
done
