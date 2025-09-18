#!/bin/bash

# Node0 Simple Manager
# Упрощенная версия менеджера

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Пути
NODE0_DIR="$HOME/node0"
CONDA_ENV="node0"

# Логотип
show_logo() {
    clear
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════╗"
    echo "║        NODE0 MANAGER v1.0             ║"
    echo "║   Децентрализованное обучение AI      ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
}

# Установка
install_node0() {
    show_logo
    echo -e "${YELLOW}🚀 Установка Node0${NC}\n"
    
    # Проверка GPU
    if ! command -v nvidia-smi &> /dev/null; then
        echo -e "${RED}Ошибка: NVIDIA драйвер не установлен!${NC}"
        echo "Установите драйвер: sudo apt install nvidia-driver-525"
        read -p "Нажмите Enter..."
        return 1
    fi
    
    echo "Установка займет 5-10 минут..."
    
    # Системные зависимости
    echo -e "\n${YELLOW}1. Установка зависимостей...${NC}"
    sudo apt update && sudo apt install -y git curl wget build-essential tmux lsof
    
    # Miniconda
    if ! command -v conda &> /dev/null; then
        echo -e "\n${YELLOW}2. Установка Miniconda...${NC}"
        wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
        bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda3
        echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/miniconda3/bin:$PATH"
        rm Miniconda3-latest-Linux-x86_64.sh
    fi
    
    # Клонирование
    echo -e "\n${YELLOW}3. Загрузка Node0...${NC}"
    [ -d "$NODE0_DIR" ] && rm -rf "$NODE0_DIR"
    git clone https://github.com/PluralisResearch/node0 "$NODE0_DIR"
    cd "$NODE0_DIR"
    
    # Python окружение
    echo -e "\n${YELLOW}4. Установка Python пакетов...${NC}"
    conda create -n $CONDA_ENV python=3.11 -y
    source ~/miniconda3/bin/activate $CONDA_ENV
    pip install .
    
    # Порт
    echo -e "\n${YELLOW}5. Открытие порта...${NC}"
    sudo ufw allow 49200/tcp && sudo ufw reload
    
    # Токен
    echo -e "\n${YELLOW}6. Настройка токена...${NC}"
    echo -e "${RED}Нужен токен HuggingFace!${NC}"
    echo "Получите здесь: https://huggingface.co/settings/tokens"
    read -p "Нажмите Enter когда готовы..."
    
    python3 generate_script.py
    
    echo -e "\n${GREEN}✅ Установка завершена!${NC}"
    read -p "Нажмите Enter..."
}

# Запуск
start_node0() {
    show_logo
    echo -e "${YELLOW}▶️  Запуск Node0${NC}\n"
    
    if [ ! -f "$NODE0_DIR/start_server.sh" ]; then
        echo -e "${RED}Node0 не установлена! Сначала установите (пункт 1)${NC}"
        read -p "Нажмите Enter..."
        return 1
    fi
    
    # Проверка запущенной
    if pgrep -f "node0" > /dev/null; then
        echo -e "${YELLOW}Node0 уже запущена!${NC}"
        read -p "Остановить и запустить заново? (y/n): " answer
        if [ "$answer" = "y" ]; then
            pkill -f "node0"
            sleep 2
        else
            return 0
        fi
    fi
    
    cd "$NODE0_DIR"
    echo -e "${YELLOW}Запуск в фоне...${NC}"
    tmux new-session -d -s node0 "./start_server.sh"
    
    echo -e "\n${GREEN}✅ Node0 запущена!${NC}"
    echo "Команды:"
    echo "  Подключиться к сессии: tmux attach -t node0"
    echo "  Отключиться: Ctrl+B, затем D"
    echo "  Проверить логи: пункт 3 в меню"
    read -p "Нажмите Enter..."
}

# Логи
view_logs() {
    show_logo
    echo -e "${YELLOW}📋 Логи Node0${NC}\n"
    
    if [ ! -f "$NODE0_DIR/logs/server.log" ]; then
        echo -e "${RED}Логи не найдены!${NC}"
        read -p "Нажмите Enter..."
        return 1
    fi
    
    echo "1) Последние 50 строк"
    echo "2) Следить в реальном времени"
    echo "3) Только ошибки"
    read -p "Выбор: " choice
    
    case $choice in
        1) tail -n 50 "$NODE0_DIR/logs/server.log" ;;
        2) 
            echo -e "\n${YELLOW}Логи в реальном времени (Ctrl+C для выхода):${NC}\n"
            tail -f "$NODE0_DIR/logs/server.log"
            ;;
        3) grep -i "error\|fail" "$NODE0_DIR/logs/server.log" | tail -20 ;;
    esac
    
    read -p "Нажмите Enter..."
}

# Удаление
remove_node0() {
    show_logo
    echo -e "${RED}🗑️  Удаление Node0${NC}\n"
    
    echo -e "${RED}Будет удалено всё, кроме private.key${NC}"
    read -p "Введите YES для подтверждения: " confirm
    
    if [ "$confirm" != "YES" ]; then
        echo "Отменено"
        read -p "Нажмите Enter..."
        return 0
    fi
    
    # Остановка
    pkill -f "node0" 2>/dev/null
    tmux kill-session -t node0 2>/dev/null
    
    # Сохранение ключа
    if [ -f "$NODE0_DIR/private.key" ]; then
        mkdir -p ~/node0_backup
        cp "$NODE0_DIR/private.key" ~/node0_backup/private.key.$(date +%Y%m%d_%H%M%S)
        echo -e "${GREEN}private.key сохранен в ~/node0_backup/${NC}"
    fi
    
    # Удаление
    rm -rf "$NODE0_DIR"
    conda remove -n $CONDA_ENV --all -y 2>/dev/null
    
    echo -e "\n${GREEN}✅ Node0 удалена${NC}"
    read -p "Нажмите Enter..."
}

# Главное меню
while true; do
    show_logo
    
    # Быстрый статус
    if pgrep -f "node0" > /dev/null; then
        echo -e "Статус: ${GREEN}● Запущена${NC}\n"
    else
        echo -e "Статус: ${RED}● Остановлена${NC}\n"
    fi
    
    echo "  1) 📦 Установить Node0"
    echo "  2) ▶️  Запустить Node0"
    echo "  3) 📋 Просмотреть логи"
    echo "  4) 🗑️  Удалить Node0"
    echo "  0) 🚪 Выход"
    echo ""
    read -p "Выбор: " choice
    
    case $choice in
        1) install_node0 ;;
        2) start_node0 ;;
        3) view_logs ;;
        4) remove_node0 ;;
        0) exit 0 ;;
    esac
done
