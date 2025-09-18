#!/bin/bash

# Node0 Manager Script - Fixed Version
# Управление установкой, запуском и удалением Node0

# Цвета для красивого вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Путь к Node0
NODE0_DIR="$HOME/node0"
CONDA_ENV="node0"

# Функция для отображения логотипа
show_logo() {
    clear
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════╗"
    echo "║        NODE0 MANAGER v1.0             ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
}

# Функция проверки статуса
check_status() {
    echo -e "\n${YELLOW}📊 Проверка статуса...${NC}"
    
    # Проверка установки conda
    if command -v conda &> /dev/null; then
        echo -e "${GREEN}✓ Conda установлена${NC}"
    else
        echo -e "${RED}✗ Conda не установлена${NC}"
    fi
    
    # Проверка окружения
    if conda env list | grep -q "$CONDA_ENV"; then
        echo -e "${GREEN}✓ Окружение node0 существует${NC}"
    else
        echo -e "${RED}✗ Окружение node0 не найдено${NC}"
    fi
    
    # Проверка директории
    if [ -d "$NODE0_DIR" ]; then
        echo -e "${GREEN}✓ Директория node0 существует${NC}"
    else
        echo -e "${RED}✗ Директория node0 не найдена${NC}"
    fi
    
    # Проверка tmux сессии и процесса start_server.sh
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "${GREEN}✓ Node0 запущена в tmux${NC}"
    elif pgrep -f "start_server.sh" > /dev/null; then
        echo -e "${GREEN}✓ Node0 запущена${NC}"
        echo "PID процессов: $(pgrep -f "start_server.sh" | tr '\n' ' ')"
    else
        echo -e "${RED}✗ Node0 не запущена${NC}"
    fi
    
    # Проверка GPU
    if command -v nvidia-smi &> /dev/null; then
        echo -e "${GREEN}✓ NVIDIA драйвер установлен${NC}"
        nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader
    else
        echo -e "${RED}✗ NVIDIA драйвер не найден${NC}"
    fi
    
    echo -e "\nНажмите Enter для продолжения..."
    read
}

# Функция установки
install_node0() {
    show_logo
    echo -e "${YELLOW}🚀 Установка Node0${NC}\n"
    
    # Проверка требований
    echo "Проверка системных требований..."
    
    # Проверка GPU
    if ! command -v nvidia-smi &> /dev/null; then
        echo -e "${RED}Ошибка: NVIDIA драйвер не установлен!${NC}"
        echo "Установите драйвер командой: sudo apt install nvidia-driver-525"
        return 1
    fi
    
    # Установка зависимостей
    echo -e "\n${YELLOW}1. Установка системных зависимостей...${NC}"
    sudo apt update && sudo apt install -y git curl wget build-essential tmux lsof
    
    # Установка Miniconda если нет
    if ! command -v conda &> /dev/null; then
        echo -e "\n${YELLOW}2. Установка Miniconda...${NC}"
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
        bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda3
        echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/miniconda3/bin:$PATH"
        rm Miniconda3-latest-Linux-x86_64.sh
    else
        echo -e "\n${GREEN}2. Miniconda уже установлена${NC}"
    fi
    
    # Клонирование репозитория
    echo -e "\n${YELLOW}3. Клонирование репозитория...${NC}"
    if [ -d "$NODE0_DIR" ]; then
        echo "Директория уже существует. Обновляем..."
        cd "$NODE0_DIR" && git pull
    else
        git clone https://github.com/PluralisResearch/node0 "$NODE0_DIR"
    fi
    
    cd "$NODE0_DIR"
    
    # Создание окружения
    echo -e "\n${YELLOW}4. Создание Python окружения...${NC}"
    conda create -n $CONDA_ENV python=3.11 -y
    
    # Установка Node0
    echo -e "\n${YELLOW}5. Установка Node0...${NC}"
    source ~/miniconda3/bin/activate $CONDA_ENV
    pip install .
    
    # Открытие порта
    echo -e "\n${YELLOW}6. Настройка файрвола...${NC}"
    sudo ufw allow 49200/tcp
    sudo ufw reload
    
    # Генерация скрипта
    echo -e "\n${YELLOW}7. Генерация скрипта запуска...${NC}"
    echo -e "${RED}Вам понадобится токен HuggingFace!${NC}"
    echo "Получите его здесь: https://huggingface.co/settings/tokens"
    echo -e "\nНажмите Enter когда будете готовы..."
    read
    
    python3 generate_script.py
    
    echo -e "\n${GREEN}✅ Установка завершена!${NC}"
    echo "Нажмите Enter для возврата в меню..."
    read
}

# Функция запуска
start_node0() {
    show_logo
    echo -e "${YELLOW}▶️  Запуск Node0${NC}\n"
    
    # Проверка установки
    if [ ! -d "$NODE0_DIR" ] || [ ! -f "$NODE0_DIR/start_server.sh" ]; then
        echo -e "${RED}Ошибка: Node0 не установлена!${NC}"
        echo "Сначала выполните установку (пункт 1)"
        echo -e "\nНажмите Enter для продолжения..."
        read
        return 1
    fi
    
    # Проверка запущенной tmux сессии или процесса
    if tmux has-session -t node0 2>/dev/null || pgrep -f "start_server.sh" > /dev/null; then
        echo -e "${YELLOW}Обнаружена работающая Node0!${NC}"
        echo -e "${YELLOW}Остановка предыдущего процесса...${NC}"
        stop_node0_process
        sleep 2
    fi
    
    cd "$NODE0_DIR"
    
    echo -e "\n${YELLOW}Запуск Node0 в tmux...${NC}"
    tmux new-session -d -s node0 "cd $NODE0_DIR && ./start_server.sh"
    
    sleep 2
    
    # Проверка успешного запуска
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "${GREEN}✅ Node0 успешно запущена в tmux сессии 'node0'${NC}"
        echo ""
        echo "Полезные команды:"
        echo "  ${GREEN}Подключиться к сессии:${NC} tmux attach -t node0"
        echo "  ${GREEN}Отключиться от сессии:${NC} Ctrl+B, затем D"
        echo "  ${GREEN}Просмотреть логи:${NC} tail -f $NODE0_DIR/logs/server.log"
    else
        echo -e "${RED}Ошибка запуска! Проверьте логи.${NC}"
    fi
    
    echo -e "\nНажмите Enter для возврата в меню..."
    read
}

# Функция остановки процесса
stop_node0_process() {
    echo -e "${YELLOW}Остановка Node0...${NC}"
    
    # Остановка tmux сессии
    if tmux has-session -t node0 2>/dev/null; then
        tmux kill-session -t node0
        echo "Tmux сессия остановлена"
    fi
    
    # Убиваем процессы start_server.sh
    if pgrep -f "start_server.sh" > /dev/null; then
        pkill -f "start_server.sh"
        echo "Процессы остановлены"
    fi
    
    # Очистка
    rm -f /tmp/hivemind* 2>/dev/null
    
    # Освобождение портов
    for i in $(lsof -t -i tcp:49200 2>/dev/null); do
        kill -9 $i 2>/dev/null
    done
    
    # Освобождение GPU
    for i in $(lsof /dev/nvidia* 2>/dev/null | grep python | awk '{print $2}' | sort -u); do
        kill -9 $i 2>/dev/null
    done
    
    echo -e "${GREEN}✅ Node0 остановлена${NC}"
}

# Функция остановки
stop_node0() {
    show_logo
    echo -e "${YELLOW}⏹️  Остановка Node0${NC}\n"
    
    if tmux has-session -t node0 2>/dev/null || pgrep -f "start_server.sh" > /dev/null; then
        stop_node0_process
    else
        echo -e "${YELLOW}Node0 не запущена${NC}"
    fi
    
    echo -e "\nНажмите Enter для возврата в меню..."
    read
}

# Функция удаления
remove_node0() {
    show_logo
    echo -e "${RED}🗑️  Удаление Node0${NC}\n"
    
    echo -e "${RED}ВНИМАНИЕ! Это действие удалит:${NC}"
    echo "- Директорию $NODE0_DIR"
    echo "- Conda окружение $CONDA_ENV"
    echo "- Все логи и данные"
    echo -e "\n${YELLOW}Важно: файл private.key будет сохранен в ~/node0_backup/${NC}"
    echo -e "\nВы уверены? (введите 'YES' для подтверждения): "
    read confirm
    
    if [ "$confirm" != "YES" ]; then
        echo "Отменено"
        echo -e "\nНажмите Enter для возврата в меню..."
        read
        return 0
    fi
    
    # Остановка если запущена
    if tmux has-session -t node0 2>/dev/null || pgrep -f "start_server.sh" > /dev/null; then
        echo -e "\n${YELLOW}Остановка процессов...${NC}"
        stop_node0_process
    fi
    
    # Сохранение private.key
    if [ -f "$NODE0_DIR/private.key" ]; then
        echo -e "\n${YELLOW}Сохранение private.key...${NC}"
        mkdir -p ~/node0_backup
        cp "$NODE0_DIR/private.key" ~/node0_backup/private.key.$(date +%Y%m%d_%H%M%S)
        echo -e "${GREEN}✓ private.key сохранен в ~/node0_backup/${NC}"
    fi
    
    # Удаление директории
    echo -e "\n${YELLOW}Удаление файлов...${NC}"
    rm -rf "$NODE0_DIR"
    
    # Удаление conda окружения
    echo -e "\n${YELLOW}Удаление conda окружения...${NC}"
    conda remove -n $CONDA_ENV --all -y 2>/dev/null
    
    echo -e "\n${GREEN}✅ Node0 удалена${NC}"
    echo -e "\nНажмите Enter для возврата в меню..."
    read
}

# Функция просмотра логов
view_logs() {
    show_logo
    echo -e "${YELLOW}📋 Просмотр логов${NC}\n"
    
    if [ ! -f "$NODE0_DIR/logs/server.log" ]; then
        echo -e "${RED}Логи не найдены!${NC}"
        echo "Node0 должна быть запущена хотя бы раз"
        echo -e "\nНажмите Enter для возврата в меню..."
        read
        return 1
    fi
    
    echo "1) Последние 50 строк"
    echo "2) Следить за логами в реальном времени"
    echo "3) Поиск ошибок"
    echo "4) Полный лог"
    echo -e "\nВыбор: "
    read choice
    
    case $choice in
        1)
            tail -n 50 "$NODE0_DIR/logs/server.log"
            ;;
        2)
            echo -e "${YELLOW}Следим за логами (Ctrl+C для выхода)...${NC}\n"
            tail -f "$NODE0_DIR/logs/server.log"
            ;;
        3)
            echo -e "${YELLOW}Ошибки в логах:${NC}\n"
            grep -i "error\|fail\|exception" "$NODE0_DIR/logs/server.log" | tail -20
            ;;
        4)
            less "$NODE0_DIR/logs/server.log"
            ;;
    esac
    
    echo -e "\nНажмите Enter для возврата в меню..."
    read
}

# Главное меню
main_menu() {
    while true; do
        show_logo
        
        echo "Выберите действие:"
        echo ""
        echo "  1) 📦 Установить Node0"
        echo "  2) ▶️  Запустить Node0"
        echo "  3) ⏹️  Остановить Node0"
        echo "  4) 📊 Проверить статус"
        echo "  5) 📋 Просмотреть логи"
        echo "  6) 🗑️  Удалить Node0"
        echo "  0) 🚪 Выход"
        echo ""
        echo -n "Ваш выбор: "
        read choice
        
        case $choice in
            1) install_node0 ;;
            2) start_node0 ;;
            3) stop_node0 ;;
            4) check_status ;;
            5) view_logs ;;
            6) remove_node0 ;;
            0) 
                echo -e "\n${GREEN}До свидания!${NC}"
                exit 0
                ;;
            *)
                echo -e "\n${RED}Неверный выбор!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Запуск
main_menu
