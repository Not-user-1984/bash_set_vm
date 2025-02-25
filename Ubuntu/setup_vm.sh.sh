#!/bin/bash

# Скрипт для автоматической настройки виртуальной машины на Ubuntu для разработки
# Устанавливает: Git, Python, Go, Docker, Fish shell, Neovim и создает пользователя с sudo правами
# Использование: ./script.sh -u <username> -p <password>

set -e  # Остановка скрипта при ошибке

# Цветные сообщения для лучшей читаемости
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Начинаем настройку виртуальной машины Ubuntu для разработки...${NC}"

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

# Обновление системы
echo -e "${YELLOW}Обновление списка пакетов и системы...${NC}"
apt-get update && apt-get upgrade -y

# Установка sudo, если его нет (в Ubuntu обычно предустановлен)
echo -e "${YELLOW}Устанавливаем sudo...${NC}"
if ! command -v sudo &> /dev/null; then
    apt-get install -y sudo
fi

# Установка необходимых инструментов
echo -e "${YELLOW}Устанавливаем базовые инструменты...${NC}"
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    build-essential \
    wget

# Установка Git
echo -e "${YELLOW}Устанавливаем Git последней версии...${NC}"
apt-get install -y git
git --version

# Установка Python и связанных инструментов
echo -e "${YELLOW}Устанавливаем Python и инструменты...${NC}"
apt-get install -y python3 python3-pip python3-venv python3-ipython python3-virtualenv

# Символические ссылки для Python
echo -e "${YELLOW}Настраиваем Python как версию по умолчанию...${NC}"
update-alternatives --install /usr/bin/python python /usr/bin/python3 1

# Установка Go
echo -e "${YELLOW}Устанавливаем Go...${NC}"
GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -n 1)
GO_TAR_FILE="${GO_VERSION}.linux-amd64.tar.gz"
GO_DOWNLOAD_URL="https://go.dev/dl/${GO_TAR_FILE}"

curl -LO ${GO_DOWNLOAD_URL}
rm -rf /usr/local/go && tar -C /usr/local -xzf ${GO_TAR_FILE}
rm ${GO_TAR_FILE}

echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh
chmod +x /etc/profile.d/go.sh
source /etc/profile.d/go.sh
go version

# Установка Docker и docker-compose
echo -e "${YELLOW}Устанавливаем Docker и docker-compose...${NC}"
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

apt-get remove -y docker docker-engine docker.io containerd runc || true

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker
systemctl start docker

# Установка Neovim
echo -e "${YELLOW}Устанавливаем Neovim...${NC}"
apt-get install -y neovim

# Установка Fish shell
echo -e "${YELLOW}Устанавливаем Fish shell...${NC}"
apt-get install -y fish

# Создание пользователя с заданными именем и паролем
echo -e "${YELLOW}Создаем пользователя $USERNAME с sudo правами...${NC}"
if id "$USERNAME" &>/dev/null; then
    echo -e "${RED}Пользователь $USERNAME уже существует${NC}"
    if ! groups $USERNAME | grep -q "\bsudo\b"; then
        usermod -aG sudo $USERNAME
        echo -e "${GREEN}Пользователь $USERNAME добавлен в группу sudo${NC}"
    else
        echo -e "${YELLOW}Пользователь $USERNAME уже в группе sudo${NC}"
    fi
    chsh -s /usr/bin/fish $USERNAME
else
    useradd -m -s /usr/bin/fish "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    usermod -aG sudo "$USERNAME"
    echo -e "${GREEN}Пользователь $USERNAME создан и добавлен в группу sudo${NC}"
    echo -e "${GREEN}Fish установлен как оболочка по умолчанию для $USERNAME${NC}"
fi

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
chsh -s /usr/bin/fish

# Дополнительные инструменты для разработки
echo -e "${YELLOW}Устанавливаем дополнительные инструменты разработчика...${NC}"
apt-get install -y \
    tmux \
    htop \
    jq \
    tree \
    git-lfs \
    neofetch

# Финальная проверка
echo -e "${GREEN}Проверяем установленные компоненты:${NC}"
echo -e "${YELLOW}Git:${NC} $(git --version)"
echo -e "${YELLOW}Python:${NC} $(python --version)"
echo -e "${YELLOW}Go:${NC} $(go version)"
echo -e "${YELLOW}Docker:${NC} $(docker --version)"
echo -e "${YELLOW}Docker Compose:${NC} $(docker compose version)"
echo -e "${YELLOW}Fish:${NC} $(fish --version)"
echo -e "${YELLOW}Neovim:${NC} $(nvim --version | head -n 1)"

echo -e "${GREEN}Настройка виртуальной машины Ubuntu завершена успешно!${NC}"
echo -e "${GREEN}Для входа в систему используйте: ${YELLOW}$USERNAME${NC}"
echo -e "${GREEN}Пароль пользователя: ${YELLOW}$PASSWORD${NC}"
echo -e "${GREEN}Fish установлен как оболочка по умолчанию.${NC}"
echo -e "${GREEN}Система готова для разработки.${NC}"