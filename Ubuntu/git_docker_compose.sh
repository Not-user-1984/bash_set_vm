#!/bin/bash

# Скрипт для установки Git и Docker Compose на Ubuntu

set -e  

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}Начинаем установку Git и Docker Compose на Ubuntu...${NC}"

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Этот скрипт должен быть запущен с правами root${NC}"
    exit 1
fi

echo -e "${YELLOW}Обновление списка пакетов...${NC}"
apt-get update

echo -e "${YELLOW}Устанавливаем базовые зависимости...${NC}"
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

echo -e "${YELLOW}Устанавливаем Git...${NC}"
apt-get install -y git
git --version

echo -e "${YELLOW}Устанавливаем Docker и Docker Compose...${NC}"
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

echo -e "${GREEN}Проверяем установленные компоненты:${NC}"
echo -e "${YELLOW}Git:${NC} $(git --version)"
echo -e "${YELLOW}Docker:${NC} $(docker --version)"
echo -e "${YELLOW}Docker Compose:${NC} $(docker compose version)"

echo -e "${GREEN}Установка Git и Docker Compose завершена успешно!${NC}"