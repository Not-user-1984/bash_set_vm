#!/bin/bash

# Скрипт для создания пользователя с sudo правами на Ubuntu
# Использование: ./create_user.sh -u <username> -p <password>

set -e  # Остановка скрипта при ошибке

# Цветные сообщения для лучшей читаемости
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Начинаем создание пользователя на Ubuntu...${NC}"

# Проверка запуска от root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Этот скрипт должен быть запущен с правами root${NC}"
    exit 1
fi

# Обработка флагов командной строки
while getopts "u:p:" opt; do
    case $opt in
        u) USERNAME="$OPTARG" ;;
        p) PASSWORD="$OPTARG" ;;
        ?) echo -e "${RED}Использование: $0 -u <username> -p <password>${NC}"; exit 1 ;;
    esac
done

# Проверка, что оба параметра переданы
if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo -e "${RED}Ошибка: необходимо указать имя пользователя (-u) и пароль (-p)${NC}"
    echo -e "${RED}Пример: $0 -u devuser -p mypassword${NC}"
    exit 1
fi

# Установка Fish shell, если не установлен
echo -e "${YELLOW}Устанавливаем Fish shell...${NC}"
apt-get update
apt-get install -y fish

# Создание пользователя с заданными именем и паролем
echo -e "${YELLOW}Создаем пользователя $USERNAME с sudo правами...${NC}"
if id "$USERNAME" &>/dev/null; then
    echo -e "${RED}Пользователь $USERNAME уже существует${NC}"
    if ! groups "$USERNAME" | grep -q "\bsudo\b"; then
        usermod -aG sudo "$USERNAME"
        echo -e "${GREEN}Пользователь $USERNAME добавлен в группу sudo${NC}"
    else
        echo -e "${YELLOW}Пользователь $USERNAME уже в группе sudo${NC}"
    fi
    chsh -s /usr/bin/fish "$USERNAME"
else
    useradd -m -s /usr/bin/fish "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    usermod -aG sudo "$USERNAME"
    echo -e "${GREEN}Пользователь $USERNAME создан и добавлен в группу sudo${NC}"
    echo -e "${GREEN}Fish установлен как оболочка по умолчанию для $USERNAME${NC}"
fi

# Настройка Fish для пользователя
sudo -u "$USERNAME" mkdir -p /home/"$USERNAME"/.config/fish

cat > /home/"$USERNAME"/.config/fish/config.fish << 'EOF'
set -gx PATH $PATH /usr/local/go/bin
set -gx GOPATH $HOME/go
set -gx PATH $PATH $GOPATH/bin
alias l='ls -lah'
alias ..='cd ..'
alias ...='cd ../..'
alias gs='git status'
alias vim='nvim'
function fish_greeting
    echo "Добро пожаловать в среду разработки на Ubuntu!"
    echo "Установлены: Git, Python, Go, Docker, Neovim"
    echo "Используйте 'sudo' для команд администратора"
end
EOF

chown "$USERNAME":"$USERNAME" /home/"$USERNAME"/.config/fish/config.fish
echo /usr/bin/fish | tee -a /etc/shells

echo -e "${GREEN}Создание пользователя $USERNAME завершено успешно!${NC}"
echo -e "${GREEN}Для входа в систему используйте: ${YELLOW}$USERNAME${NC}"
echo -e "${GREEN}Пароль пользователя: ${YELLOW}$PASSWORD${NC}"