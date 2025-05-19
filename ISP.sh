#!/bin/bash

# Супер пупер крутой скрипт для настройки сети на Eltex/Linux
# Автор: Grok, создан для автоматизации конфигурации сетевых интерфейсов и firewalld
# Логирование и проверка ошибок включены

# Настройки
LOG_FILE="/var/log/network_config_$(date +%Y%m%d_%H%M%S).log"
HOSTNAME="ISP"
TIMEZONE="Europe/Moscow"
SYSCTL_CONF="/etc/sysctl.conf"

# Цвета для вывода в консоль
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция логирования
log() {
    local message="$1"
    local status="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
    if [ "$status" == "SUCCESS" ]; then
        echo -e "${GREEN}[УСПЕХ]${NC} $message"
    elif [ "$status" == "ERROR" ]; then
        echo -e "${RED}[ОШИБКА]${NC} $message"
        exit 1
    else
        echo -e "${YELLOW}[ИНФО]${NC} $message"
    fi
}

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    log "Скрипт должен быть запущен от имени root" "ERROR"
fi

# Создание лог-файла
touch "$LOG_FILE" 2>/dev/null || log "Не удалось создать лог-файл $LOG_FILE" "ERROR"
log "Запуск скрипта настройки сети" "INFO"

# Проверка наличия необходимых утилит
for cmd in nmcli firewall-cmd systemctl timedatectl; do
    if ! command -v "$cmd" &>/dev/null; then
        log "Утилита $cmd не найдена" "ERROR"
    fi
done

# --- Часть 1: Настройка hostname ---
log "Установка hostname: $HOSTNAME" "INFO"
hostnamectl set-hostname "$HOSTNAME"
if [ $? -eq 0 ]; then
    log "Hostname успешно установлен: $HOSTNAME" "SUCCESS"
else
    log "Не удалось установить hostname" "ERROR"
fi

# --- Часть 2: Удаление существующих подключений ---
log "Удаление всех существующих сетевых подключений" "INFO"
for conn in $(nmcli -t -f NAME con show); do
    nmcli con delete "$conn" &>/dev/null
    if [ $? -eq 0 ]; then
        log "Подключение $conn удалено" "SUCCESS"
    else
        log "Ошибка при удалении подключения $conn" "ERROR"
    fi
done

# --- Часть 3: Создание новых подключений ---
# 3.1: ens18 (автоматическая настройка IPv4, IPv6 отключен)
log "Создание подключения для ens18" "INFO"
nmcli con add type ethernet con-name ens18 ifname ens18 ipv4.method auto ipv6.method disabled
if [ $? -eq 0 ]; then
    log "Подключение ens18 успешно создано" "SUCCESS"
else
    log "Ошибка при создании подключения ens18" "ERROR"
fi

# 3.2: ens19 (ручная настройка IPv4, IPv6 отключен)
log "Создание подключения для ens19" "INFO"
nmcli con add type ethernet con-name ens19 ifname ens19 ipv4.method manual ipv4.addresses 172.16.4.1/28 ipv6.method disabled
if [ $? -eq 0 ]; then
    log "Подключение ens19 успешно создано" "SUCCESS"
else
    log "Ошибка при создании подключения ens19" "ERROR"
fi

# 3.3: ens20 (ручная настройка IPv4, IPv6 отключен)
log "Создание подключения для ens20" "INFO"
nmcli con add type ethernet con-name ens20 ifname ens20 ipv4.method manual ipv4.addresses 172.16.5.1/28 ipv6.method disabled
if [ $? -eq 0 ]; then
    log "Подключение ens20 успешно создано" "SUCCESS"
else
    log "Ошибка при создании подключения ens20" "ERROR"
fi

# Перезапуск сетевых адаптеров
log "Перезапуск сетевых адаптеров" "INFO"
nmcli con up ens18 &>/dev/null && nmcli con up ens19 &>/dev/null && nmcli con up ens20 &>/dev/null
if [ $? -eq 0 ]; then
    log "Сетевые адаптеры успешно перезапущены" "SUCCESS"
else
    log "Ошибка при перезапуске сетевых адаптеров" "ERROR"
fi

# --- Часть 4: Настройка firewalld ---
log "Включение и запуск firewalld" "INFO"
systemctl enable --now firewalld
if [ $? -eq 0 ]; then
    log "firewalld успешно включен и запущен" "SUCCESS"
else
    log "Ошибка при включении/запуске firewalld" "ERROR"
fi

# Назначение зон для интерфейсов
log "Назначение зоны external для ens18" "INFO"
firewall-cmd --zone=external --change-interface=ens18 --permanent
if [ $? -eq 0 ]; then
    log "Зона external для ens18 успешно назначена" "SUCCESS"
else
    log "Ошибка при назначении зоны external для ens18" "ERROR"
fi

log "Назначение зоны internal для ens19" "INFO"
firewall-cmd --zone=internal --change-interface=ens19 --permanent
if [ $? -eq 0 ]; then
    log "Зона internal для ens19 успешно назначена" "SUCCESS"
else
    log "Ошибка при назначении зоны internal для ens19" "ERROR"
fi

log "Назначение зоны internal для ens20" "INFO"
firewall-cmd --zone=internal --change-interface=ens20 --permanent
if [ $? -eq 0 ]; then
    log "Зона internal для ens20 успешно назначена" "SUCCESS"
else
    log "Ошибка при назначении зоны internal для ens20" "ERROR"
fi

log "Включение форвардинга в зоне internal" "INFO"
firewall-cmd --zone=internal --add-forward --permanent
if [ $? -eq 0 ]; then
    log "Форвардинг в зоне internal успешно включен" "SUCCESS"
else
    log "Ошибка при включении форвардинга" "ERROR"
fi

log "Перезагрузка firewalld" "INFO"
firewall-cmd --reload
if [ $? -eq 0 ]; then
    log "firewalld успешно перезагружен" "SUCCESS"
else
    log "Ошибка при перезагрузке firewalld" "ERROR"
fi

log "Проверка активных зон firewalld" "INFO"
firewall-cmd --get-active-zones >> "$LOG_FILE"
if [ $? -eq 0 ]; then
    log "Активные зоны firewalld успешно выведены в лог" "SUCCESS"
else
    log "Ошибка при выводе активных зон" "ERROR"
fi

# --- Часть 5: Настройка sysctl.conf ---
log "Редактирование $SYSCTL_CONF" "INFO"
if [ ! -f "$SYSCTL_CONF" ]; then
    log "Файл $SYSCTL_CONF не существует" "ERROR"
fi

# Создаем временную копию sysctl.conf
cp "$SYSCTL_CONF" "${SYSCTL_CONF}.bak" || log "Не удалось создать резервную копию $SYSCTL_CONF" "ERROR"
log "Создана резервная копия $SYSCTL_CONF" "SUCCESS"

# Замена значений в sysctl.conf
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' "$SYSCTL_CONF"
if [ $? -eq 0 ]; then
    log "Параметр net.ipv4.ip_forward успешно изменен на 1" "SUCCESS"
else
    log "Ошибка при изменении net.ipv4.ip_forward" "ERROR"
fi

sed -i 's/net.ipv4.conf.default.rp_filter = 1/net.ipv4.conf.default.rp_filter = 0/' "$SYSCTL_CONF"
if [ $? -eq 0 ]; then
    log "Параметр net.ipv4.conf.default.rp_filter успешно изменен на 0" "SUCCESS"
else
    log "Ошибка при изменении net.ipv4.conf.default.rp_filter" "ERROR"
fi

# Применение изменений sysctl
sysctl -p "$SYSCTL_CONF" &>/dev/null
if [ $? -eq 0 ]; then
    log "Параметры sysctl успешно применены" "SUCCESS"
else
    log "Ошибка при применении параметров sysctl" "ERROR"
fi

# --- Часть 6: Установка часового пояса ---
log "Установка часового пояса: $TIMEZONE" "INFO"
timedatectl set-timezone "$TIMEZONE"
if [ $? -eq 0 ]; then
    log "Часовой пояс успешно установлен: $TIMEZONE" "SUCCESS"
else
    log "Ошибка при установке часового пояса" "ERROR"
fi

# --- Часть 7: Перезагрузка системы ---
log "Все настройки завершены, необходима перезагрузка" "INFO"
log "Скрипт завершен, логи сохранены в $LOG_FILE" "SUCCESS"
read -p "Перезагрузить систему сейчас? (y/n): " answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    log "Перезагрузка системы" "INFO"
    reboot
else
    log "Перезагрузка отменена пользователем" "INFO"
fi