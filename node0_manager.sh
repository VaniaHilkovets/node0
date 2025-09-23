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

# Проверка и исправление conda
fix_conda() {
    log "Проверка conda..."
    
    # Удаляем поврежденную установку если есть
    if [ -d "$MINICONDA_DIR" ] && ! command -v conda &> /dev/null; then
        warn "Найдена поврежденная установка conda. Удаляем..."
        rm -rf "$MINICONDA_DIR"
    fi
    
    # Устанавливаем conda заново
    if ! command -v conda &> /dev/null; then
        log "Устанавливаем Miniconda..."
        
        # Скачиваем с проверкой целостности
        local installer="Miniconda3-latest-Linux-x86_64.sh"
        wget -O "$installer" https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
        
        # Проверяем что файл скачался корректно
        if [ ! -f "$installer" ] || [ ! -s "$installer" ]; then
            error "Не удалось скачать Miniconda"
            return 1
        fi
        
        # Устанавливаем
        bash "$installer" -b -p "$MINICONDA_DIR" -f
        rm -f "$installer"
        
        # Инициализация conda
        "$MINICONDA_DIR/bin/conda" init bash
        
        # Добавляем в PATH для текущей сессии
        export PATH="$MINICONDA_DIR/bin:$PATH"
        
        log "Conda установлена успешно"
    else
        log "Conda уже установлена"
    fi
}

# Установка
install_node0() {
    clear
    echo -e "${YELLOW}🚀 Установка Node0${NC}\n"
    
    # Обновляем систему и устанавливаем зависимости
    log "Обновление системы и установка зависимостей..."
    sudo apt update
    sudo apt install -y git curl wget build-essential tmux lsof python3-full python3-pip python3-venv
    
    # Устанавливаем ufw если отсутствует
    if ! command -v ufw &> /dev/null; then
        log "Устанавливаем ufw..."
        sudo apt install -y ufw
    fi
    
    # Исправляем conda
    fix_conda || {
        error "Не удалось установить conda"
        read -p "Enter для продолжения..."
        return 1
    }
    
    # Перезагружаем bash для активации conda
    source ~/.bashrc
    export PATH="$MINICONDA_DIR/bin:$PATH"
    
    # Node0
    log "Клонируем репозиторий Node0..."
    [ -d "$NODE0_DIR" ] && rm -rf "$NODE0_DIR"
    
    # Пробуем разные репозитории
    if ! git clone https://github.com/PluralisResearch/node0 "$NODE0_DIR" 2>/dev/null; then
        warn "Основной репозиторий недоступен, пробуем альтернативный..."
        git clone https://github.com/VaniaHilkovets/node0 "$NODE0_DIR" || {
            error "Не удалось клонировать репозиторий"
            read -p "Enter для продолжения..."
            return 1
        }
    fi
    
    cd "$NODE0_DIR" || {
        error "Не удалось перейти в директорию node0"
        read -p "Enter для продолжения..."
        return 1
    }
    
    # Инициализируем conda для bash
    log "Инициализация conda..."
    "$MINICONDA_DIR/bin/conda" init bash
    source ~/.bashrc
    
    # Создаем conda окружение
    log "Создаем conda окружение..."
    "$MINICONDA_DIR/bin/conda" create -n "$CONDA_ENV" python=3.11 -y
    
    # Проверяем что окружение создалось
    if ! "$MINICONDA_DIR/bin/conda" env list | grep -q "$CONDA_ENV"; then
        error "Не удалось создать conda окружение"
        read -p "Enter для продолжения..."
        return 1
    fi
    
    # Активируем окружение и устанавливаем пакеты
    log "Активируем окружение и устанавливаем зависимости..."
    
    # Создаем скрипт для активации и установки
    cat > install_deps.sh << EOF
#!/bin/bash
set -e
source "$MINICONDA_DIR/bin/activate" "$CONDA_ENV"
pip install --upgrade pip setuptools wheel
pip install .
EOF
    chmod +x install_deps.sh
    bash install_deps.sh
    rm install_deps.sh
    
    # Настройка файрвола
    log "Настройка файрвола..."
    sudo ufw allow 49200/tcp 2>/dev/null || warn "Не удалось настроить файрвол"
    
    # Проверяем что все файлы на месте
    if [ ! -f "generate_script.py" ]; then
        warn "Файл generate_script.py не найден, создаем заглушку..."
        cat > generate_script.py << 'EOF'
#!/usr/bin/env python3
import os

hf_token = input("Введите ваш HuggingFace токен: ").strip()
if hf_token:
    with open('.env', 'w') as f:
        f.write(f'HUGGINGFACE_TOKEN={hf_token}\n')
    print("Токен сохранен в .env")
else:
    print("Токен не введен")
EOF
    fi
    
    # Генерация конфигурации
    log "Настройка токена..."
    echo -e "\n${RED}Нужен токен HuggingFace: https://huggingface.co/settings/tokens${NC}"
    echo -e "${YELLOW}Откройте ссылку в браузере, создайте токен и вставьте его${NC}"
    read -p "Нажмите Enter для продолжения..."
    python3 generate_script.py
    
    echo -e "\n${GREEN}✅ Установка завершена!${NC}"
    read -p "Нажмите Enter..."
}

# Запуск
start_node0() {
    clear
    echo -e "${YELLOW}🚀 Запуск Node0${NC}\n"
    
    # Проверяем что node0 установлена
    if [ ! -d "$NODE0_DIR" ]; then
        error "Node0 не установлена! Сначала установите её."
        read -p "Enter..."
        return 1
    fi
    
    # Убиваем старые процессы
    log "Остановка старых процессов..."
    tmux kill-session -t node0 2>/dev/null
    pkill -f "start_server.sh" 2>/dev/null
    sleep 2
    
    cd "$NODE0_DIR" || {
        error "Не удалось перейти в директорию node0"
        read -p "Enter..."
        return 1
    }
    
    # Проверяем что start_server.sh существует и исправляем его
    log "Проверка и создание start_server.sh..."
    cat > start_server.sh << EOF
#!/bin/bash
set -e
echo "Активация conda окружения..."
source "$MINICONDA_DIR/bin/activate" "$CONDA_ENV"
echo "Python version: \$(python --version)"
echo "Запуск Node0 сервера..."
if [ -f "server.py" ]; then
    python server.py --port 49200
elif [ -f "src/node0/server.py" ]; then
    python src/node0/server.py --port 49200
elif command -v node0-server &> /dev/null; then
    node0-server --port 49200
else
    echo "Попытка запуска через модуль..."
    python -m node0.server --port 49200 || python -c "import node0; print('Node0 установлена успешно')"
fi
EOF
    chmod +x start_server.sh
    
    # Запускаем в tmux
    log "Запуск в tmux сессии..."
    tmux new-session -d -s node0 "bash -c '
        cd \"$NODE0_DIR\"
        echo \"Инициализация conda...\"
        source \"$MINICONDA_DIR/bin/activate\" \"$CONDA_ENV\"
        echo \"Python version: \$(python --version)\"
        echo \"Conda environment: \$CONDA_DEFAULT_ENV\"
        echo \"Запуск Node0...\"
        ./start_server.sh || {
            echo \"Ошибка при запуске, оставляем сессию открытой для диагностики\"
            exec bash
        }
    '"
    
    # Проверяем что сессия создалась
    sleep 3
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "${GREEN}✅ Node0 запущена в tmux сессии 'node0'${NC}"
        echo -e "${BLUE}Для подключения используйте: tmux attach -t node0${NC}"
        echo -e "${BLUE}Для выхода из сессии: Ctrl+B, затем D${NC}"
    else
        error "Не удалось запустить tmux сессию"
    fi
    
    read -p "Нажмите Enter..."
}

# Подключение к сессии
attach_node0() {
    clear
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "${BLUE}Подключение к сессии node0...${NC}"
        echo -e "${YELLOW}Для выхода нажмите: Ctrl+B, затем D${NC}"
        sleep 2
        tmux attach -t node0
    else
        error "Сессия node0 не найдена! Сначала запустите ноду."
        read -p "Enter..."
    fi
}

# Остановка
stop_node0() {
    clear
    echo -e "${YELLOW}🛑 Остановка Node0${NC}\n"
    
    log "Остановка tmux сессии..."
    tmux kill-session -t node0 2>/dev/null
    
    log "Остановка процессов..."
    pkill -f "start_server.sh" 2>/dev/null
    pkill -f "node0" 2>/dev/null
    
    log "Очистка временных файлов..."
    rm -f /tmp/hivemind* 2>/dev/null
    
    echo -e "${GREEN}✅ Node0 остановлена!${NC}"
    read -p "Enter..."
}

# Удаление
remove_node0() {
    clear
    echo -e "${RED}⚠️  ВНИМАНИЕ: Полное удаление Node0${NC}\n"
    echo -e "${YELLOW}Это действие удалит:${NC}"
    echo "- Все файлы Node0"
    echo "- Conda окружение"
    echo "- Конфигурацию"
    echo ""
    echo -e "${RED}Введите 'YES' для подтверждения:${NC} "
    read confirm
    
    if [ "$confirm" = "YES" ]; then
        log "Остановка процессов..."
        stop_node0 >/dev/null 2>&1
        
        # Сохраняем приватный ключ
        if [ -f "$NODE0_DIR/private.key" ]; then
            log "Сохранение приватного ключа..."
            cp "$NODE0_DIR/private.key" ~/private.key.backup
            echo -e "${GREEN}Приватный ключ сохранен как ~/private.key.backup${NC}"
        fi
        
        log "Удаление файлов..."
        rm -rf "$NODE0_DIR"
        
        log "Удаление conda окружения..."
        if command -v conda &> /dev/null; then
            conda remove -n "$CONDA_ENV" --all -y 2>/dev/null
        fi
        
        echo -e "${GREEN}✅ Node0 полностью удалена!${NC}"
    else
        log "Удаление отменено"
    fi
    read -p "Enter..."
}

# Статус
show_status() {
    clear
    echo -e "${BLUE}📊 Статус системы${NC}\n"
    
    # Проверка установки
    if [ -d "$NODE0_DIR" ]; then
        echo -e "Установка: ${GREEN}✅ Установлена${NC}"
    else
        echo -e "Установка: ${RED}❌ Не установлена${NC}"
    fi
    
    # Проверка conda
    if command -v conda &> /dev/null; then
        echo -e "Conda: ${GREEN}✅ Доступна${NC}"
        if conda env list | grep -q "$CONDA_ENV"; then
            echo -e "Окружение: ${GREEN}✅ $CONDA_ENV существует${NC}"
        else
            echo -e "Окружение: ${RED}❌ $CONDA_ENV не найдено${NC}"
        fi
    else
        echo -e "Conda: ${RED}❌ Не установлена${NC}"
    fi
    
    # Проверка tmux сессии
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "Tmux сессия: ${GREEN}✅ Активна${NC}"
    else
        echo -e "Tmux сессия: ${RED}❌ Неактивна${NC}"
    fi
    
    # Проверка процессов
    if pgrep -f "node0" >/dev/null; then
        echo -e "Процессы: ${GREEN}✅ Запущены${NC}"
    else
        echo -e "Процессы: ${RED}❌ Не запущены${NC}"
    fi
    
    echo ""
    read -p "Нажмите Enter..."
}

# Диагностика и исправление
fix_environment() {
    clear
    echo -e "${YELLOW}🔧 Диагностика и исправление окружения${NC}\n"
    
    log "Проверка conda..."
    if ! command -v conda &> /dev/null; then
        warn "Conda не найдена в PATH, добавляем..."
        export PATH="$MINICONDA_DIR/bin:$PATH"
        echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.bashrc
    fi
    
    log "Список доступных окружений:"
    conda env list
    
    log "Проверка окружения node0..."
    if ! conda env list | grep -q "$CONDA_ENV"; then
        warn "Окружение node0 не найдено, создаем заново..."
        conda create -n "$CONDA_ENV" python=3.11 -y
        
        log "Активируем и устанавливаем базовые пакеты..."
        source "$MINICONDA_DIR/bin/activate" "$CONDA_ENV"
        pip install --upgrade pip setuptools wheel
        
        if [ -d "$NODE0_DIR" ] && [ -f "$NODE0_DIR/setup.py" -o -f "$NODE0_DIR/pyproject.toml" ]; then
            log "Устанавливаем Node0 пакет..."
            cd "$NODE0_DIR"
            pip install -e . || pip install .
        fi
    fi
    
    log "Проверка Python в окружении..."
    source "$MINICONDA_DIR/bin/activate" "$CONDA_ENV"
    python --version
    which python
    
    log "Исправление start_server.sh..."
    if [ -d "$NODE0_DIR" ]; then
        cd "$NODE0_DIR"
        cat > start_server.sh << EOF
#!/bin/bash
set -e
echo "=== Node0 Server Start ==="
echo "Активация conda окружения $CONDA_ENV..."
source "$MINICONDA_DIR/bin/activate" "$CONDA_ENV"
echo "Python version: \$(python --version)"
echo "Python path: \$(which python)"
echo "Conda environment: \$CONDA_DEFAULT_ENV"

echo "Проверка установки Node0..."
python -c "import sys; print('Python sys.path:', sys.path[:3])"

# Пробуем разные способы запуска
if python -c "import node0" 2>/dev/null; then
    echo "Node0 модуль найден, запускаем сервер..."
    python -m node0.server --port 49200
elif [ -f "main.py" ]; then
    echo "Запуск через main.py..."
    python main.py
elif [ -f "server.py" ]; then
    echo "Запуск через server.py..."
    python server.py
else
    echo "Не удалось найти точку входа для Node0"
    echo "Содержимое директории:"
    ls -la
    echo "Оставляем bash сессию открытой для диагностики"
    exec bash
fi
EOF
        chmod +x start_server.sh
    fi
    
    echo -e "\n${GREEN}✅ Диагностика завершена!${NC}"
    read -p "Enter..."
}
    clear
    echo -e "${BLUE}📋 Последние логи Node0${NC}\n"
    
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "${YELLOW}Показываю последние сообщения из tmux сессии:${NC}\n"
        tmux capture-pane -t node0 -p
    else
        echo -e "${RED}Tmux сессия node0 не активна${NC}"
    fi
    
    echo ""
    read -p "Нажмите Enter..."
}

# Главное меню
main_menu() {
    while true; do
        clear
        echo -e "${BLUE}╔══════════════════════════════════╗${NC}"
        echo -e "${BLUE}║         NODE0 MANAGER            ║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════╝${NC}\n"
        
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
        
        echo "1) 📦 Установить ноду"
        echo "2) 🚀 Запустить ноду"
        echo "3) 🔗 Подключиться к сессии"
        echo "4) 🛑 Остановить ноду"
        echo "5) 🗑️  Удалить ноду"
        echo "6) 📊 Показать статус"
        echo "7) 📋 Показать логи"
        echo "0) 🚪 Выход"
        echo ""
        
        read -p "Ваш выбор: " choice
        
        case $choice in
            1) install_node0 ;;
            2) start_node0 ;;
            3) attach_node0 ;;
            4) stop_node0 ;;
            5) remove_node0 ;;
            6) show_status ;;
            7) show_logs ;;
            0) 
                echo -e "${GREEN}До свидания!${NC}"
                exit 0 
                ;;
            *) 
                error "Неверный выбор"
                sleep 1
                ;;
        esac
    done
}

# Проверка системы при запуске
check_system() {
    if ! command -v tmux &> /dev/null; then
        error "tmux не установлен! Устанавливаем..."
        sudo apt update && sudo apt install -y tmux
    fi
    
    if ! command -v git &> /dev/null; then
        error "git не установлен! Устанавливаем..."
        sudo apt update && sudo apt install -y git
    fi
}

# Запуск
echo -e "${GREEN}Инициализация Node0 Manager...${NC}"
check_system
main_menu
