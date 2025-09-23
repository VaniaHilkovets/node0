#!/bin/bash
# Node0 Pluralis Manager v4 - Полная версия с автоматической регистрацией
# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

# Проверка и инициализация conda
init_conda() {
    if [ -f "$CONDA_HOME/bin/conda" ]; then
        eval "$($CONDA_HOME/bin/conda shell.bash hook)"
        return 0
    fi
    return 1
}

# Полная установка всех зависимостей
install_all_dependencies() {
    clear
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║     УСТАНОВКА ВСЕХ ЗАВИСИМОСТЕЙ NODE0        ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}Будут установлены:${NC}"
    echo "  • Системные пакеты и утилиты"
    echo "  • Python 3 и pip"
    echo "  • NVIDIA CUDA Toolkit (если нужно)"
    echo "  • Miniconda для управления окружением"
    echo "  • Git и инструменты разработки"
    echo ""
    read -p "Продолжить? (y/n): " continue_install
    
    if [ "$continue_install" != "y" ] && [ "$continue_install" != "Y" ]; then
        return
    fi
    
    # Определяем наличие sudo
    HAS_SUDO=false
    if command -v sudo &> /dev/null; then
        HAS_SUDO=true
    fi
    
    # 1. Обновление системы
    log "Обновление списка пакетов..."
    if [ "$HAS_SUDO" = true ]; then
        sudo apt update && sudo apt upgrade -y
    else
        apt update && apt upgrade -y
    fi
    success "Система обновлена"
    
    # 2. Установка основных утилит
    log "Установка основных системных утилит..."
    PACKAGES="screen curl iptables build-essential git wget lz4 jq make gcc nano \
              automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev \
              libleveldb-dev tar clang bsdmainutils ncdu unzip lsof net-tools"
    
    if [ "$HAS_SUDO" = true ]; then
        sudo apt install -y $PACKAGES
    else
        apt install -y $PACKAGES
    fi
    success "Основные утилиты установлены"
    
    # 3. Установка Python и pip
    log "Установка Python и pip..."
    PYTHON_PACKAGES="python3-pip python3-dev python3-venv python3-setuptools"
    
    if [ "$HAS_SUDO" = true ]; then
        sudo apt install -y $PYTHON_PACKAGES
    else
        apt install -y $PYTHON_PACKAGES
    fi
    
    # Обновляем pip
    python3 -m pip install --upgrade pip 2>/dev/null || pip install --upgrade pip 2>/dev/null
    success "Python и pip установлены"
    
    # 4. Проверка и установка NVIDIA драйверов и CUDA
    log "Проверка NVIDIA GPU..."
    if command -v nvidia-smi &> /dev/null; then
        success "NVIDIA драйвер обнаружен"
        nvidia-smi
        
        # Проверяем CUDA
        if ! command -v nvcc &> /dev/null; then
            warning "CUDA Toolkit не установлен"
            read -p "Установить CUDA Toolkit? (y/n): " install_cuda
            
            if [ "$install_cuda" = "y" ] || [ "$install_cuda" = "Y" ]; then
                log "Установка CUDA Toolkit..."
                if [ "$HAS_SUDO" = true ]; then
                    sudo apt install -y nvidia-cuda-toolkit
                else
                    apt install -y nvidia-cuda-toolkit
                fi
                success "CUDA Toolkit установлен"
            fi
        else
            success "CUDA Toolkit обнаружен"
            nvcc --version
        fi
    else
        warning "NVIDIA GPU не обнаружен или драйверы не установлены"
        echo "Для работы Node0 требуется NVIDIA GPU с минимум 16GB VRAM"
        echo ""
        read -p "Попробовать установить NVIDIA драйверы? (y/n): " install_nvidia
        
        if [ "$install_nvidia" = "y" ] || [ "$install_nvidia" = "Y" ]; then
            if [ "$HAS_SUDO" = true ]; then
                sudo apt install -y nvidia-driver-525 nvidia-cuda-toolkit
            else
                apt install -y nvidia-driver-525 nvidia-cuda-toolkit
            fi
            warning "Драйверы установлены. Требуется перезагрузка системы!"
            echo "После перезагрузки запустите скрипт снова"
        fi
    fi
    
    # 5. Установка Miniconda
    if [ ! -f "$CONDA_HOME/bin/conda" ]; then
        log "Установка Miniconda..."
        mkdir -p ~/miniconda3
        wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
        bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
        rm ~/miniconda3/miniconda.sh
        
        # Инициализируем conda
        "$CONDA_HOME/bin/conda" init bash
        "$CONDA_HOME/bin/conda" init --all
        
        source ~/.bashrc
        success "Miniconda установлена"
    else
        success "Miniconda уже установлена"
    fi
    
    # 6. Дополнительные библиотеки для Python
    log "Установка дополнительных Python библиотек..."
    if [ "$HAS_SUDO" = true ]; then
        sudo apt install -y python3-numpy python3-scipy python3-matplotlib
    else
        apt install -y python3-numpy python3-scipy python3-matplotlib
    fi
    success "Дополнительные библиотеки установлены"
    
    # 7. Проверка портов
    log "Проверка доступности порта 49200..."
    if lsof -i:49200 &> /dev/null; then
        warning "Порт 49200 занят. Освобождаем..."
        for pid in $(lsof -t -i tcp:49200); do
            kill -9 $pid 2>/dev/null || true
        done
        success "Порт 49200 освобожден"
    else
        success "Порт 49200 свободен"
    fi
    
    # 8. Финальная проверка
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ Все зависимости успешно установлены!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Проверка компонентов:${NC}"
    
    # Проверяем установленные компоненты
    echo -n "  Python: "
    if command -v python3 &> /dev/null; then
        echo -e "${GREEN}✓${NC} $(python3 --version)"
    else
        echo -e "${RED}✗${NC}"
    fi
    
    echo -n "  Git: "
    if command -v git &> /dev/null; then
        echo -e "${GREEN}✓${NC} $(git --version)"
    else
        echo -e "${RED}✗${NC}"
    fi
    
    echo -n "  Conda: "
    if [ -f "$CONDA_HOME/bin/conda" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
    
    echo -n "  NVIDIA GPU: "
    if command -v nvidia-smi &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}Не обнаружен${NC}"
    fi
    
    echo -n "  CUDA: "
    if command -v nvcc &> /dev/null; then
        echo -e "${GREEN}✓${NC} $(nvcc --version | head -n1)"
    else
        echo -e "${YELLOW}Не установлен${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Теперь можно устанавливать Node0 (пункт 2)${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# Создание скрипта запуска с автоматическим перезапуском
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
    
    # Создаем wrapper с автоматическим перезапуском при ошибке регистрации
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

# Функция для запуска с повторными попытками
run_with_retry() {
    local attempt=0
    local max_attempts=1000  # Большое количество попыток
    
    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Попытка регистрации #$attempt"
        
        # Запускаем скрипт
        ./start_server.sh
        exit_code=$?
        
        # Если процесс завершился с ошибкой
        if [ $exit_code -ne 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Процесс завершился с кодом $exit_code"
            
            # Проверяем логи на предмет ошибки регистрации
            if tail -n 50 logs/server.log 2>/dev/null | grep -q "Retrying\|Failed to join\|Connection error\|Registration failed"; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Обнаружена ошибка регистрации. Повторная попытка через 30 секунд..."
                sleep 30
                
                # Очищаем временные файлы перед повторной попыткой
                rm -f /tmp/hivemind* 2>/dev/null || true
                
                # Убиваем зависшие процессы на порту
                for pid in $(lsof -t -i tcp:49200 2>/dev/null); do
                    kill -9 $pid 2>/dev/null || true
                done
                
                continue
            fi
        fi
        
        # Если процесс работает нормально
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Node0 запущена успешно!"
        break
    done
    
    if [ $attempt -eq $max_attempts ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Достигнуто максимальное количество попыток ($max_attempts)"
        exit 1
    fi
}

# Запускаем с повторными попытками
run_with_retry
EOF
    
    chmod +x start_node0_wrapper.sh
    
    # Создаем скрипт для автоматической регистрации
    cat > auto_register.sh << 'EOF'
#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${MAGENTA}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║      АВТОМАТИЧЕСКАЯ РЕГИСТРАЦИЯ NODE0        ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}Процесс будет пытаться зарегистрировать ноду пока не успешно${NC}"
echo -e "${YELLOW}Для остановки нажмите Ctrl+C${NC}\n"

# Счетчики
attempt=0
success=false
start_time=$(date +%s)

# Функция для проверки успешной регистрации
check_registration() {
    if [ -f logs/server.log ]; then
        # Проверяем признаки успешной регистрации
        if tail -n 100 logs/server.log | grep -q "Successfully joined\|Connected to\|Training started\|Peer connected"; then
            return 0
        fi
    fi
    return 1
}

# Функция для вывода статистики
show_stats() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    local hours=$((elapsed / 3600))
    local minutes=$(( (elapsed % 3600) / 60 ))
    local seconds=$((elapsed % 60))
    
    echo -e "\n${CYAN}═══════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Статистика попыток:${NC}"
    echo -e "  Попыток: ${YELLOW}$attempt${NC}"
    echo -e "  Времени прошло: ${YELLOW}${hours}ч ${minutes}м ${seconds}с${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}\n"
}

# Основной цикл регистрации
while [ "$success" = false ]; do
    attempt=$((attempt + 1))
    
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] Попытка регистрации #$attempt${NC}"
    
    # Очищаем перед попыткой
    echo "Очистка временных файлов..."
    rm -f /tmp/hivemind* 2>/dev/null || true
    for pid in $(lsof -t -i tcp:49200 2>/dev/null); do
        kill -9 $pid 2>/dev/null || true
    done
    
    # Активируем conda
    export PATH="$HOME/miniconda3/bin:$PATH"
    eval "$($HOME/miniconda3/bin/conda shell.bash hook)"
    conda activate node0
    
    # Запускаем ноду в фоне
    echo "Запуск Node0..."
    timeout 120 ./start_server.sh > register.log 2>&1 &
    pid=$!
    
    # Прогресс-бар
    echo -n "Проверка регистрации "
    
    # Ждем и проверяем статус
    for i in {1..60}; do
        if check_registration; then
            echo ""
            echo -e "${GREEN}✅ Успешная регистрация после $attempt попыток!${NC}"
            echo -e "${GREEN}Node0 подключена к сети и начала работу${NC}"
            success=true
            break 2
        fi
        
        # Проверяем, работает ли процесс
        if ! kill -0 $pid 2>/dev/null; then
            echo ""
            echo -e "${YELLOW}Процесс завершился. Проверяем логи...${NC}"
            if grep -q "Retrying" register.log 2>/dev/null; then
                echo "Нода в очереди на подключение..."
            fi
            break
        fi
        
        # Показываем прогресс
        if [ $((i % 10)) -eq 0 ]; then
            echo -n "[$i/60]"
        else
            echo -n "."
        fi
        sleep 2
    done
    
    echo ""
    
    # Если не успешно, ждем перед повторной попыткой
    if [ "$success" = false ]; then
        # Останавливаем процесс если еще работает
        kill $pid 2>/dev/null || true
        
        # Показываем статистику каждые 10 попыток
        if [ $((attempt % 10)) -eq 0 ]; then
            show_stats
        fi
        
        echo -e "${YELLOW}Регистрация не удалась. Повторная попытка через 30 секунд...${NC}"
        
        # Показываем последние строки лога
        if [ -f logs/server.log ]; then
            echo -e "${CYAN}Последние записи в логе:${NC}"
            tail -n 5 logs/server.log | sed 's/^/  /'
        fi
        
        # Обратный отсчет
        echo -n "Ожидание: "
        for i in {30..1}; do
            echo -n "$i "
            sleep 1
        done
        echo ""
    fi
done

show_stats
echo -e "\n${GREEN}🎉 Node0 успешно зарегистрирована и работает!${NC}"
echo -e "${CYAN}Dashboard: https://dashboard.pluralis.ai/${NC}"
echo -e "\n${YELLOW}Нода продолжит работать. Используйте tmux для управления.${NC}"
EOF
    
    chmod +x auto_register.sh
    
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
    
    # 1. Проверяем основные зависимости
    if ! command -v git &> /dev/null || ! command -v python3 &> /dev/null; then
        error "Не все зависимости установлены!"
        echo "Сначала запустите пункт 1 для установки всех зависимостей"
        read -p "Enter..."
        return
    fi
    
    # 2. Проверяем и устанавливаем Conda если нет
    if [ ! -f "$CONDA_HOME/bin/conda" ]; then
        log "Conda не найдена. Устанавливаем..."
        mkdir -p ~/miniconda3
        wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
        bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
        rm ~/miniconda3/miniconda.sh
        "$CONDA_HOME/bin/conda" init bash
        source ~/.bashrc
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
    log "Устанавливаем Node0 и зависимости..."
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
    echo -e "${YELLOW}Используйте пункт 3 или 4 для запуска${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# Обычный запуск Node0
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
        echo ""
        warning "Если нода не регистрируется, используйте пункт 4 для автоматической регистрации"
    else
        error "Не удалось запустить Node0!"
        echo "Проверьте логи для деталей"
    fi
    
    read -p "Нажмите Enter для продолжения..."
}

# Автоматическая регистрация Node0 (новый улучшенный)
auto_register_node0() {
    clear
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║       АВТОМАТИЧЕСКАЯ РЕГИСТРАЦИЯ NODE0       ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════╝${NC}\n"
    
    if [ ! -d "$NODE0_DIR" ]; then
        error "Node0 не установлена! Сначала выполните установку (пункт 2)."
        read -p "Enter..."
        return
    fi
    
    cd "$NODE0_DIR"
    
    if [ ! -f "auto_register.sh" ]; then
        error "Скрипт автоматической регистрации не найден!"
        echo "Переустановите Node0 или запустите обычным способом"
        read -p "Enter..."
        return
    fi
    
    # Останавливаем текущие сессии если есть
    log "Останавливаем текущие процессы..."
    tmux kill-session -t node0 2>/dev/null || true
    tmux kill-session -t node0_register 2>/dev/null || true
    rm -f /tmp/hivemind* 2>/dev/null || true
    
    # Убиваем процессы на порту
    if command -v lsof &> /dev/null; then
        for pid in $(lsof -t -i tcp:49200 2>/dev/null); do
            kill -9 $pid 2>/dev/null || true
        done
    fi
    
    echo -e "${YELLOW}Этот режим будет автоматически пытаться зарегистрировать ноду${NC}"
    echo -e "${YELLOW}пока регистрация не будет успешной.${NC}"
    echo ""
    echo -e "${CYAN}Особенности:${NC}"
    echo "  • Автоматическая очистка при ошибках"
    echo "  • Повторные попытки каждые 30 секунд"
    echo "  • Статистика попыток каждые 10 попыток"
    echo "  • Автоматическое определение успешной регистрации"
    echo ""
    echo -e "${BLUE}Режимы запуска:${NC}"
    echo "  1) 👁️  Интерактивный (видно весь процесс)"
    echo "  2) 📦 Фоновый (работает в tmux)"
    echo "  3) 🚀 Быстрый запуск в фоне"
    echo "  0) ❌ Отмена"
    echo ""
    read -p "Выберите режим: " reg_choice
    
    case $reg_choice in
        1)
            # Интерактивный режим
            log "Запуск автоматической регистрации в интерактивном режиме..."
            echo -e "${YELLOW}Для остановки нажмите Ctrl+C${NC}"
            sleep 2
            ./auto_register.sh
            ;;
        2)
            # Фоновый режим в tmux
            log "Запуск автоматической регистрации в tmux..."
            tmux new-session -d -s node0_register "cd $NODE0_DIR && ./auto_register.sh"
            sleep 2
            
            if tmux has-session -t node0_register 2>/dev/null; then
                echo -e "${GREEN}✅ Процесс регистрации запущен!${NC}\n"
                echo -e "${BLUE}Команды управления:${NC}"
                echo -e "  Подключиться к процессу: ${YELLOW}tmux attach -t node0_register${NC}"
                echo -e "  Отключиться: ${YELLOW}Ctrl+B, затем D${NC}"
                echo -e "  Проверить логи: ${YELLOW}tail -f $NODE0_DIR/logs/server.log${NC}"
                echo ""
                echo -e "${CYAN}Процесс будет работать пока нода не зарегистрируется${NC}"
                echo ""
                read -p "Подключиться к процессу сейчас? (y/n): " attach_now
                if [ "$attach_now" = "y" ] || [ "$attach_now" = "Y" ]; then
                    tmux attach -t node0_register
                fi
            else
                error "Не удалось запустить процесс регистрации!"
            fi
            ;;
        3)
            # Быстрый запуск
            log "Быстрый запуск автоматической регистрации..."
            tmux new-session -d -s node0_register "cd $NODE0_DIR && ./auto_register.sh"
            echo -e "${GREEN}✅ Запущено в фоне!${NC}"
            echo -e "Используйте ${YELLOW}tmux attach -t node0_register${NC} для подключения"
            sleep 2
            ;;
        0)
            return
            ;;
        *)
            error "Неверный выбор!"
            ;;
    esac
    
    read -p "Нажмите Enter для продолжения..."
}

# Остановка Node0
stop_node0() {
    log "Останавливаем все процессы Node0..."
    
    # Останавливаем все tmux сессии
    tmux kill-session -t node0 2>/dev/null || true
    tmux kill-session -t node0_register 2>/dev/null || true
    
    # Очищаем временные файлы
    rm -f /tmp/hivemind* 2>/dev/null || true
    
    # Убиваем процессы на порту
    if command -v lsof &> /dev/null; then
        for pid in $(lsof -t -i tcp:49200 2>/dev/null); do
            kill -9 $pid 2>/dev/null || true
        done
    fi
    
    # Убиваем все процессы python связанные с node0
    pkill -f "start_server.sh" 2>/dev/null || true
    pkill -f "auto_register.sh" 2>/dev/null || true
    pkill -f "start_node0" 2>/dev/null || true
    
    success "Все процессы Node0 остановлены"
}

# Подключение к tmux
connect_tmux() {
    clear
    echo -e "${BLUE}=== Выбор сессии для подключения ===${NC}\n"
    
    # Проверяем какие сессии активны
    has_node0=false
    has_register=false
    
    if tmux has-session -t node0 2>/dev/null; then
        has_node0=true
        echo -e "${GREEN}1) Основная сессия Node0${NC}"
    fi
    
    if tmux has-session -t node0_register 2>/dev/null; then
        has_register=true
        echo -e "${CYAN}2) Сессия автоматической регистрации${NC}"
    fi
    
    if [ "$has_node0" = false ] && [ "$has_register" = false ]; then
        error "Нет активных сессий!"
        echo -e "${YELLOW}Сначала запустите Node0 (пункт 3 или 4)${NC}"
        read -p "Enter..."
        return
    fi
    
    echo "0) Назад"
    echo ""
    read -p "Выбор: " session_choice
    
    case $session_choice in
        1)
            if [ "$has_node0" = true ]; then
                echo -e "${BLUE}Подключаемся к Node0...${NC}"
                echo -e "${YELLOW}Для выхода используйте: Ctrl+B, затем D${NC}"
                sleep 2
                tmux attach -t node0
            else
                error "Эта сессия не активна!"
                read -p "Enter..."
            fi
            ;;
        2)
            if [ "$has_register" = true ]; then
                echo -e "${BLUE}Подключаемся к процессу регистрации...${NC}"
                echo -e "${YELLOW}Для выхода используйте: Ctrl+B, затем D${NC}"
                sleep 2
                tmux attach -t node0_register
            else
                error "Эта сессия не активна!"
                read -p "Enter..."
            fi
            ;;
        0)
            return
            ;;
        *)
            error "Неверный выбор!"
            read -p "Enter..."
            ;;
    esac
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
    
    echo "1) 📄 Последние 50 строк основного лога"
    echo "2) 🔄 Следить за логами в реальном времени"
    echo "3) 📚 Полный лог"
    echo "4) 📋 Лог регистрации (если есть)"
    echo "5) 🔍 Поиск в логах"
    echo "0) ↩️  Назад"
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
        4)
            if [ -f "$NODE0_DIR/register.log" ]; then
                less "$NODE0_DIR/register.log"
            else
                echo "Лог регистрации не найден"
                read -p "Enter..."
            fi
            ;;
        5)
            if [ -f "$NODE0_DIR/logs/server.log" ]; then
                read -p "Введите текст для поиска: " search_text
                grep -n "$search_text" "$NODE0_DIR/logs/server.log" | less
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
            # Показываем первые символы ключа
            key_preview=$(head -c 20 "$NODE0_DIR/private.key" | xxd -p | head -c 10)
            echo -e "Key preview: ${CYAN}${key_preview}...${NC}"
        else
            echo -e "Private key: ${YELLOW}Отсутствует (будет создан при первом запуске)${NC}"
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
    
    # GPU статус
    echo -n "GPU: "
    if command -v nvidia-smi &> /dev/null; then
        gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
        gpu_mem=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader | head -n1)
        echo -e "${GREEN}$gpu_name ($gpu_mem)${NC}"
    else
        echo -e "${RED}Не обнаружен${NC}"
    fi
    
    # Tmux сессии
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "Основной процесс: ${GREEN}🟢 Работает${NC}"
        # Проверяем время работы
        if [ -f "$NODE0_DIR/logs/server.log" ]; then
            uptime=$(ps aux | grep "[s]tart_server.sh" | awk '{print $9}' | head -n1)
            [ ! -z "$uptime" ] && echo -e "  Запущен: ${CYAN}$uptime${NC}"
        fi
    else
        echo -e "Основной процесс: ${RED}🔴 Остановлен${NC}"
    fi
    
    if tmux has-session -t node0_register 2>/dev/null; then
        echo -e "Процесс регистрации: ${CYAN}🔄 Активен${NC}"
    fi
    
    # Конфигурация
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo -e "Конфигурация: ${GREEN}Сохранена${NC}"
        echo -e "  Email: ${CYAN}${SAVED_EMAIL}${NC}"
        [ ! -z "$SAVED_ANNOUNCE_PORT" ] && echo -e "  Announce port: ${CYAN}${SAVED_ANNOUNCE_PORT}${NC}"
    else
        echo -e "Конфигурация: ${YELLOW}Не найдена${NC}"
    fi
    
    # Проверяем подключение к сети
    if [ -f "$NODE0_DIR/logs/server.log" ]; then
        if tail -n 100 "$NODE0_DIR/logs/server.log" 2>/dev/null | grep -q "Successfully joined\|Training started"; then
            echo -e "Статус сети: ${GREEN}✅ Подключено и работает${NC}"
        elif tail -n 50 "$NODE0_DIR/logs/server.log" 2>/dev/null | grep -q "Retrying"; then
            echo -e "Статус сети: ${YELLOW}⏳ В очереди на подключение${NC}"
        fi
    fi
    
    echo ""
}

# Главное меню
while true; do
    clear
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║       NODE0 PLURALIS MANAGER v4.0            ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════╝${NC}\n"
    
    check_status
    
    echo -e "${YELLOW}🔧 Установка и настройка:${NC}"
    echo "  1) 📦 Установить ВСЕ зависимости"
    echo "  2) 🚀 Установить Node0"
    echo ""
    echo -e "${GREEN}▶️  Запуск:${NC}"
    echo "  3) ▶️  Запустить Node0 (обычный)"
    echo "  4) 🔄 Автоматическая регистрация ${CYAN}(РЕКОМЕНДУЕТСЯ)${NC}"
    echo ""
    echo -e "${BLUE}📊 Мониторинг:${NC}"
    echo "  5) 📺 Подключиться к консоли"
    echo "  6) 📄 Просмотр логов"
    echo ""
    echo -e "${CYAN}⚙️  Управление:${NC}"
    echo "  7) 🔄 Обновить Node0"
    echo "  8) ⏹️  Остановить Node0"
    echo "  9) 🗑️  Удалить Node0"
    echo ""
    echo "  0) ❌ Выход"
    echo ""
    
    read -p "Выберите действие: " choice
    
    case $choice in
        1) install_all_dependencies ;;
        2) install_node0 ;;
        3) start_node0 ;;
        4) auto_register_node0 ;;
        5) connect_tmux ;;
        6) view_logs ;;
        7) update_node0 ;;
        8) 
            stop_node0
            echo -e "${GREEN}Node0 остановлена${NC}"
            read -p "Enter..."
            ;;
        9) remove_node0 ;;
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
