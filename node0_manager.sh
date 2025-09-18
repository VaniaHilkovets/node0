#!/bin/bash

# Node0 Minimal Manager

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Пути
NODE0_DIR="$HOME/node0"
CONDA_ENV="node0"

# Установка
install_node0() {
    clear
    echo -e "${YELLOW}🚀 Установка Node0${NC}\n"
    
    # Зависимости
    sudo apt update && sudo apt install -y git curl wget build-essential tmux lsof
    
    # Miniconda
    if ! command -v conda &> /dev/null; then
        wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
        bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda3
        echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/miniconda3/bin:$PATH"
        rm Miniconda3-latest-Linux-x86_64.sh
    fi
    
    # Node0
    [ -d "$NODE0_DIR" ] && rm -rf "$NODE0_DIR"
    git clone https://github.com/PluralisResearch/node0 "$NODE0_DIR"
    cd "$NODE0_DIR"
    conda create -n $CONDA_ENV python=3.11 -y
    source ~/miniconda3/bin/activate $CONDA_ENV
    pip install .
    
    # Порт
    sudo ufw allow 49200/tcp && sudo ufw reload
    
    # Токен
    echo -e "\n${RED}Нужен токен HuggingFace: https://huggingface.co/settings/tokens${NC}"
    read -p "Enter для продолжения..."
    python3 generate_script.py
    
    echo -e "\n${GREEN}✅ Готово!${NC}"
    read -p "Enter..."
}

# Запуск
start_node0() {
    clear
    # Убиваем старые процессы
    tmux kill-session -t node0 2>/dev/null
    pkill -f "start_server.sh" 2>/dev/null
    
    cd "$NODE0_DIR"
    tmux new-session -d -s node0 "./start_server.sh"
    echo -e "${GREEN}✅ Запущено!${NC}"
    sleep 2
}

# Подключение к сессии
attach_node0() {
    if tmux has-session -t node0 2>/dev/null; then
        tmux attach -t node0
    else
        echo -e "${RED}Нода не запущена!${NC}"
        read -p "Enter..."
    fi
}

# Остановка
stop_node0() {
    clear
    tmux kill-session -t node0 2>/dev/null
    pkill -f "start_server.sh" 2>/dev/null
    rm -f /tmp/hivemind* 2>/dev/null
    echo -e "${GREEN}✅ Остановлено!${NC}"
    read -p "Enter..."
}

# Удаление
remove_node0() {
    clear
    echo -e "${RED}Удалить Node0? (YES для подтверждения):${NC} "
    read confirm
    if [ "$confirm" = "YES" ]; then
        stop_node0
        [ -f "$NODE0_DIR/private.key" ] && cp "$NODE0_DIR/private.key" ~/private.key.backup
        rm -rf "$NODE0_DIR"
        conda remove -n $CONDA_ENV --all -y 2>/dev/null
        echo -e "${GREEN}✅ Удалено! (private.key сохранен как ~/private.key.backup)${NC}"
    fi
    read -p "Enter..."
}

# Меню
while true; do
    clear
    echo -e "${BLUE}NODE0 MANAGER${NC}\n"
    
    if tmux has-session -t node0 2>/dev/null; then
        echo -e "Статус: ${GREEN}● Работает${NC}\n"
    else
        echo -e "Статус: ${RED}● Остановлена${NC}\n"
    fi
    
    echo "1) Установить ноду"
    echo "2) Запустить ноду"
    echo "3) Подключиться к сесии"
    echo "4) Остановить ноду"
    echo "5) Удалить ноду"
    echo "0) Выход"
    
    read -p "Выбор: " choice
    
    case $choice in
        1) install_node0 ;;
        2) start_node0 ;;
        3) attach_node0 ;;
        4) stop_node0 ;;
        5) remove_node0 ;;
        0) exit 0 ;;
    esac
done
