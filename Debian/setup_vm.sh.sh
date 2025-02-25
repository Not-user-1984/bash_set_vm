#!/bin/bash

# Скрипт для автоматической настройки виртуальной машины на Debian для разработки
# Устанавливает: Git, Python, Go, Docker, Fish shell, Neovim и создает пользователя с sudo правами

set -e  # Остановка скрипта при ошибке

# Цветные сообщения для лучшей читаемости
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Начинаем настройку виртуальной машины Debian для разработки...${NC}"

# Проверка запуска от root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Этот скрипт должен быть запущен с правами root${NC}"
    exit 1
fi

# Обновление системы
echo -e "${YELLOW}Обновление списка пакетов и системы...${NC}"
apt-get update && apt-get upgrade -y

# Установка sudo, если его нет
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
    wget \
    gnupg2

# Установка Git
echo -e "${YELLOW}Устанавливаем Git последней версии...${NC}"
apt-get install -y git

# Добавляем backports для более новой версии Git (опционально)
if grep -q "bookworm\|bullseye" /etc/os-release; then
    echo "deb http://deb.debian.org/debian $(lsb_release -cs)-backports main" | tee /etc/apt/sources.list.d/backports.list
    apt-get update
    apt-get -t $(lsb_release -cs)-backports install -y git
fi

git --version

# Установка Python и связанных инструментов
echo -e "${YELLOW}Устанавливаем Python и инструменты...${NC}"
apt-get install -y python3 python3-pip python3-venv ipython3 python3-virtualenv

# Установка pipx
echo -e "${YELLOW}Устанавливаем pipx...${NC}"
apt-get install -y pipx

# Символические ссылки для Python
echo -e "${YELLOW}Настраиваем Python как версию по умолчанию...${NC}"
update-alternatives --install /usr/bin/python python /usr/bin/python3 1

# Установка Go
echo -e "${YELLOW}Устанавливаем Go...${NC}"
# Получаем последнюю версию Go
GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -n 1)
GO_TAR_FILE="${GO_VERSION}.linux-amd64.tar.gz"
GO_DOWNLOAD_URL="https://go.dev/dl/${GO_TAR_FILE}"

curl -LO ${GO_DOWNLOAD_URL}
rm -rf /usr/local/go && tar -C /usr/local -xzf ${GO_TAR_FILE}
rm ${GO_TAR_FILE}

# Добавление Go в PATH
echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh
chmod +x /etc/profile.d/go.sh
source /etc/profile.d/go.sh
go version

# Установка Docker
echo -e "${YELLOW}Устанавливаем Docker...${NC}"
# Установка зависимостей
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Удаление старых версий Docker, если они есть
apt-get remove -y docker docker-engine docker.io containerd runc || true

# Добавление официального GPG ключа Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Настройка репозитория Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установка Docker Engine и плагина docker-compose
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker
systemctl start docker

# Установка Neovim вместо Vim
echo -e "${YELLOW}Устанавливаем Neovim...${NC}"
apt-get install -y neovim

# Установка Fish shell
echo -e "${YELLOW}Устанавливаем Fish shell...${NC}"

# В Debian необходимо добавить репозиторий для получения последней версии Fish
echo 'deb http://download.opensuse.org/repositories/shells:/fish:/release:/3/Debian_11/ /' | tee /etc/apt/sources.list.d/shells:fish:release:3.list
curl -fsSL https://download.opensuse.org/repositories/shells:fish:release:3/Debian_11/Release.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/shells_fish_release_3.gpg > /dev/null
apt-get update
apt-get install -y fish

# Интерактивное создание пользователя
echo -e "${YELLOW}Теперь создадим пользователя с sudo правами${NC}"
echo -e "${GREEN}Введите имя пользователя:${NC}"
read -p "Имя пользователя: " USERNAME

# Проверка, существует ли уже пользователь
if id "$USERNAME" &>/dev/null; then
    echo -e "${RED}Пользователь $USERNAME уже существует${NC}"
    
    # Добавляем существующего пользователя в группу sudo, если его там нет
    if ! groups $USERNAME | grep -q "\bsudo\b"; then
        usermod -aG sudo $USERNAME
        echo -e "${GREEN}Пользователь $USERNAME добавлен в группу sudo${NC}"
    else
        echo -e "${YELLOW}Пользователь $USERNAME уже в группе sudo${NC}"
    fi
    
    # Устанавливаем fish как оболочку по умолчанию
    chsh -s /usr/bin/fish $USERNAME
else
    # Создание пользователя и добавление его в sudo группу
    useradd -m -s /usr/bin/fish $USERNAME
    passwd $USERNAME
    usermod -aG sudo $USERNAME
    
    echo -e "${GREEN}Пользователь $USERNAME создан и добавлен в группу sudo${NC}"
    echo -e "${GREEN}Fish установлен как оболочка по умолчанию для $USERNAME${NC}"
fi

# Настройка Fish для пользователя
sudo -u $USERNAME mkdir -p /home/$USERNAME/.config/fish

# Базовая конфигурация Fish
cat > /home/$USERNAME/.config/fish/config.fish << 'EOF'
# Настройки Fish shell
set -gx PATH $PATH /usr/local/go/bin
set -gx GOPATH $HOME/go
set -gx PATH $PATH $GOPATH/bin

# Алиасы
alias l='ls -lah'
alias ..='cd ..'
alias ...='cd ../..'
alias gs='git status'
alias vim='nvim'  # Использовать nvim вместо vim

# Приветствие
function fish_greeting
    echo "Добро пожаловать в среду разработки на Debian!"
    echo "Установлены: Git, Python, Go, Docker, Neovim"
    echo "Используйте 'sudo' для команд администратора"
end
EOF

# Устанавливаем владельца для конфигурационного файла
chown $USERNAME:$USERNAME /home/$USERNAME/.config/fish/config.fish

# Установка Fish как оболочки по умолчанию для системы
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

# Финальная настройка и проверка
echo -e "${GREEN}Проверяем установленные компоненты:${NC}"
echo -e "${YELLOW}Git:${NC} $(git --version)"
echo -e "${YELLOW}Python:${NC} $(python --version)"
echo -e "${YELLOW}Go:${NC} $(go version)"
echo -e "${YELLOW}Docker:${NC} $(docker --version)"
echo -e "${YELLOW}Fish:${NC} $(fish --version)"
echo -e "${YELLOW}Neovim:${NC} $(nvim --version | head -n 1)"

echo -e "${GREEN}Настройка виртуальной машины Debian завершена успешно!${NC}"
echo -e "${GREEN}Для входа в систему используйте: ${YELLOW}$USERNAME${NC}"
echo -e "${GREEN}Fish установлен как оболочка по умолчанию.${NC}"
echo -e "${GREEN}Система готова для разработки.${NC}"