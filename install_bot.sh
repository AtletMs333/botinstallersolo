#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Функция для проверки успешности выполнения команды
check_status() {
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "$2"
        exit 1
    fi
}

# Директория с конфигами
CONFIG_DIR="/root"

echo "=========================================="
echo "  Автоматическая установка SoloNet Bot"
echo "=========================================="
echo ""

# ==================== СБОР ДАННЫХ ====================
print_info "Начинаем сбор необходимых данных..."
echo ""

# Домен
read -p "Введите домен бота (например, my.domen.com): " BOT_DOMAIN
while [ -z "$BOT_DOMAIN" ]; do
    print_error "Домен не может быть пустым!"
    read -p "Введите домен бота: " BOT_DOMAIN
done

# Путь для подписки
read -p "Введите путь для подписки (например, my_beautiful_path): " SUB_PATH
while [ -z "$SUB_PATH" ]; do
    print_error "Путь не может быть пустым!"
    read -p "Введите путь для подписки: " SUB_PATH
done

# Порт бота
read -p "Введите порт бота (по умолчанию 3001): " BOT_PORT
BOT_PORT=${BOT_PORT:-3001}

# Название папки бота
read -p "Введите название папки для бота (по умолчанию Solo_bot): " BOT_FOLDER
BOT_FOLDER=${BOT_FOLDER:-Solo_bot}

# Полный путь к папке бота
BOT_PATH="/root/$BOT_FOLDER"

# Версия бота
echo ""
print_info "Выберите версию бота:"
echo "1) Релизная версия (main)"
echo "2) Бета версия (dev)"
read -p "Ваш выбор (1 или 2): " VERSION_CHOICE
while [[ ! "$VERSION_CHOICE" =~ ^[12]$ ]]; do
    print_error "Неверный выбор! Введите 1 или 2."
    read -p "Ваш выбор (1 или 2): " VERSION_CHOICE
done

if [ "$VERSION_CHOICE" == "1" ]; then
    BOT_BRANCH="main"
    print_info "Выбрана релизная версия"
else
    BOT_BRANCH="dev"
    print_info "Выбрана бета версия"
fi

# PostgreSQL данные
echo ""
print_info "Настройка базы данных PostgreSQL:"
read -p "Введите имя пользователя БД: " DB_USER
while [ -z "$DB_USER" ]; do
    print_error "Имя пользователя не может быть пустым!"
    read -p "Введите имя пользователя БД: " DB_USER
done

read -p "Введите название базы данных: " DB_NAME
while [ -z "$DB_NAME" ]; do
    print_error "Название БД не может быть пустым!"
    read -p "Введите название базы данных: " DB_NAME
done

read -sp "Введите пароль для БД: " DB_PASSWORD
echo ""
while [ -z "$DB_PASSWORD" ]; do
    print_error "Пароль не может быть пустым!"
    read -sp "Введите пароль для БД: " DB_PASSWORD
    echo ""
done

# Проверка наличия config.py и texts.py
echo ""
print_info "Проверка наличия необходимых файлов..."
if [ ! -f "$CONFIG_DIR/config.py" ]; then
    print_error "Файл config.py не найден в /root/"
    print_error "Загрузите config.py в /root/ и запустите скрипт снова"
    exit 1
fi
print_success "Файл config.py найден"

if [ ! -f "$CONFIG_DIR/texts.py" ]; then
    print_error "Файл texts.py не найден в /root/"
    print_error "Загрузите texts.py в /root/ и запустите скрипт снова"
    exit 1
fi
print_success "Файл texts.py найден"

# Подтверждение
echo ""
echo "=========================================="
print_info "Проверьте введенные данные:"
echo "Домен: $BOT_DOMAIN"
echo "Путь подписки: $SUB_PATH"
echo "Порт: $BOT_PORT"
echo "Папка бота: $BOT_PATH"
echo "Ветка: $BOT_BRANCH"
echo "Пользователь БД: $DB_USER"
echo "Название БД: $DB_NAME"
echo "=========================================="
echo ""
read -p "Все верно? Продолжить установку? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    print_warning "Установка отменена пользователем"
    exit 0
fi

# ==================== УСТАНОВКА ====================
echo ""
print_info "Начинаем установку..."

# Обновление системы
print_info "Обновление системы..."
sudo apt update -y
check_status "Система обновлена" "Ошибка обновления системы"

# ==================== УСТАНОВКА CADDY ====================
print_info "Установка Caddy..."

# Попытка быстрой установки
sudo apt install -y caddy 2>/dev/null

if [ $? -ne 0 ]; then
    print_warning "Быстрая установка не удалась, добавляем официальный репозиторий..."
    
    sudo apt install -y curl debian-keyring debian-archive-keyring apt-transport-https
    check_status "Установлены зависимости" "Ошибка установки зависимостей"
    
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    check_status "GPG ключ добавлен" "Ошибка добавления GPG ключа"
    
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    check_status "Репозиторий добавлен" "Ошибка добавления репозитория"
    
    sudo apt update -y
    sudo apt install -y caddy
    check_status "Caddy установлен" "Ошибка установки Caddy"
else
    print_success "Caddy установлен"
fi

# Настройка Caddy
print_info "Настройка Caddy..."
sudo tee /etc/caddy/Caddyfile > /dev/null <<EOF
https://$BOT_DOMAIN {
       # Проксирование запросов на вебхук Telegram
       reverse_proxy /webhook/* localhost:$BOT_PORT

       # Проксирование запросов на вебхук YooKassa
       reverse_proxy /yookassa/webhook localhost:$BOT_PORT

       # Проксирование запросов на вебхук YooMoney
       reverse_proxy /yoomoney/webhook localhost:$BOT_PORT

       # Проксирование запросов на вебхук Robokassa
       reverse_proxy /robokassa/webhook localhost:$BOT_PORT

       # Проксирование запросов на вебхук Freekassa
       reverse_proxy /freekassa/webhook localhost:$BOT_PORT

       # Проксирование запросов на вебхук Crypto Bot
       reverse_proxy /cryptobot/webhook localhost:$BOT_PORT

       # Проксирование запросов на вебхук WATA
       reverse_proxy /wata/webhook localhost:$BOT_PORT

       # Проксирование запросов на вебхук KassaAI
       reverse_proxy /kassai/webhook localhost:$BOT_PORT

       # Проксирование запросов на вебхук Heleket
       reverse_proxy /heleket/webhook localhost:$BOT_PORT

       # Проксирование запросов на вебхук Tribute
       reverse_proxy /tribute/webhook localhost:$BOT_PORT

       # Проксирование запросов на вебхук TBlocker
       reverse_proxy /tblocker/webhook localhost:$BOT_PORT

       # Путь подписки в рамках бота
       reverse_proxy /$SUB_PATH/* http://localhost:$BOT_PORT

       @has_url query url=*
       redir @has_url {query.url} 301

       respond / 404 "URL argument is missing."
}
EOF

sudo systemctl restart caddy
check_status "Caddy настроен и перезапущен" "Ошибка перезапуска Caddy"

# ==================== УСТАНОВКА POSTGRESQL ====================
print_info "Установка PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib
check_status "PostgreSQL установлен" "Ошибка установки PostgreSQL"

sudo systemctl start postgresql
sudo systemctl enable postgresql
check_status "PostgreSQL запущен" "Ошибка запуска PostgreSQL"

# Настройка PostgreSQL
print_info "Настройка базы данных..."
sudo -u postgres psql <<EOF
CREATE USER $DB_USER;
ALTER USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
\q
EOF
check_status "База данных настроена" "Ошибка настройки базы данных"

# ==================== НАСТРОЙКА ВРЕМЕНИ ====================
print_info "Настройка часового пояса..."
sudo timedatectl set-timezone UTC
check_status "Часовой пояс установлен на UTC" "Ошибка настройки часового пояса"

# ==================== УСТАНОВКА PYTHON 3.12 ====================
print_info "Установка Python 3.12..."
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update -y
sudo apt install -y python3.12 python3.12-venv
check_status "Python 3.12 установлен" "Ошибка установки Python 3.12"

# Установка локали
print_info "Настройка локали..."
sudo locale-gen ru_RU.UTF-8
check_status "Локаль настроена" "Ошибка настройки локали"

# ==================== КЛОНИРОВАНИЕ РЕПОЗИТОРИЯ ====================
print_info "Установка Git..."
sudo apt install -y git
check_status "Git установлен" "Ошибка установки Git"

print_info "Создание папки бота и клонирование репозитория..."
mkdir -p "$BOT_PATH"
cd "$BOT_PATH"
git clone -b $BOT_BRANCH https://github.com/Vladless/Solo_bot.git .
check_status "Репозиторий клонирован" "Ошибка клонирования репозитория"

# ==================== КОПИРОВАНИЕ ФАЙЛОВ ====================
print_info "Копирование config.py..."
cp "$CONFIG_DIR/config.py" "$BOT_PATH/config.py"
check_status "config.py скопирован в $BOT_PATH" "Ошибка копирования config.py"

print_info "Копирование texts.py..."
mkdir -p "$BOT_PATH/handlers"
cp "$CONFIG_DIR/texts.py" "$BOT_PATH/handlers/texts.py"
check_status "texts.py скопирован в $BOT_PATH/handlers" "Ошибка копирования texts.py"

# ==================== ВИРТУАЛЬНОЕ ОКРУЖЕНИЕ ====================
print_info "Создание виртуального окружения..."
cd "$BOT_PATH"
python3.12 -m venv venv
check_status "Виртуальное окружение создано" "Ошибка создания виртуального окружения"

print_info "Активация виртуального окружения и установка библиотек..."
source venv/bin/activate
curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12
pip install -r requirements.txt
check_status "Библиотеки установлены" "Ошибка установки библиотек"

# ==================== СОЗДАНИЕ SYSTEMD СЕРВИСА ====================
print_info "Создание systemd сервиса..."
sudo tee /etc/systemd/system/bot.service > /dev/null <<EOF
[Unit]
Description=SoloBot Service
After=network.target

[Service]
User=root
WorkingDirectory=$BOT_PATH
ExecStart=$BOT_PATH/venv/bin/python $BOT_PATH/main.py
ExecStop=/bin/kill -s SIGINT \$MAINPID
Restart=always
KillMode=control-group
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable bot.service
check_status "Systemd сервис создан" "Ошибка создания systemd сервиса"

# ==================== ЗАВЕРШЕНИЕ ====================
echo ""
echo "=========================================="
print_success "Установка завершена успешно!"
echo "=========================================="
echo ""
print_info "Папка бота: $BOT_PATH"
print_info "Файлы config.py и texts.py скопированы"
echo ""
print_warning "ВАЖНО: Перед запуском бота отредактируйте config.py и добавьте:"
echo "  - BOT_TOKEN"
echo "  - Данные подключения к БД (если еще не указаны)"
echo "  - API ключи платежных систем"
echo "  - Другие необходимые параметры"
echo ""
print_info "Для редактирования config.py выполните:"
echo "  nano $BOT_PATH/config.py"
echo ""
print_info "Для запуска бота выполните:"
echo "  sudo systemctl start bot.service"
echo ""
print_info "Для просмотра логов бота:"
echo "  sudo journalctl -u bot.service -f"
echo ""
print_info "Для перезапуска бота:"
echo "  sudo systemctl restart bot.service"
echo ""
print_info "Для проверки статуса бота:"
echo "  sudo systemctl status bot.service"
echo ""
print_success "Хорошего дня!"
