#!/bin/bash
# Скрипт настройки сети для ALT Linux / Eltex с цветным выводом статусов

# Настройки
LOG_FILE="/var/log/network_config_$(date +%Y%m%d_%H%M%S).log"
HOSTNAME="ISP"
TIMEZONE="Europe/Moscow"
SYSCTL_CONF="/etc/sysctl.conf"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Сброс цвета

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ОШИБКА] Скрипт должен быть запущен от root${NC}"
    exit 1
fi

touch "$LOG_FILE" 2>/dev/null || { echo -e "${RED}[ОШИБКА] Не удалось создать лог-файл $LOG_FILE${NC}"; exit 1; }
echo -e "${YELLOW}[INFO] Запуск скрипта настройки сети${NC}"

# Проверка утилит
for cmd in nmcli firewall-cmd systemctl timedatectl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}[ОШИБКА] Утилита $cmd не найдена${NC}"
        exit 1
    fi
done

# Установка hostname
echo -e "${YELLOW}[INFO] Установка hostname: $HOSTNAME${NC}"
hostnamectl set-hostname "$HOSTNAME" && \
    echo -e "${GREEN}[УСПЕХ] Hostname установлен${NC}" || \
    { echo -e "${RED}[ОШИБКА] Не удалось установить hostname${NC}"; exit 1; }

# Удаление старых сетевых подключений
echo -e "${YELLOW}[INFO] Удаление всех сетевых подключений${NC}"
for conn in $(nmcli -t -f NAME con show); do
    if nmcli con delete "$conn" &>> "$LOG_FILE"; then
        echo -e "${GREEN}[УСПЕХ] Удалено подключение: $conn${NC}"
    else
        echo -e "${RED}[ОШИБКА] Не удалось удалить подключение: $conn${NC}"
    fi
done

# Создание новых подключений
for iface in ens18 ens19 ens20; do
    echo -e "${YELLOW}[INFO] Настройка интерфейса $iface${NC}"
done

nmcli con add type ethernet con-name ens18 ifname ens18 ipv4.method auto ipv6.method disabled && \
    echo -e "${GREEN}[УСПЕХ] ens18 создан (IPv4 авто, IPv6 отключен)${NC}" || \
    echo -e "${RED}[ОШИБКА] ens18 не создан${NC}"

nmcli con add type ethernet con-name ens19 ifname ens19 ipv4.method manual ipv4.addresses 172.16.4.1/28 ipv6.method disabled && \
    echo -e "${GREEN}[УСПЕХ] ens19 создан (ручной IPv4)${NC}" || \
    echo -e "${RED}[ОШИБКА] ens19 не создан${NC}"

nmcli con add type ethernet con-name ens20 ifname ens20 ipv4.method manual ipv4.addresses 172.16.5.1/28 ipv6.method disabled && \
    echo -e "${GREEN}[УСПЕХ] ens20 создан (ручной IPv4)${NC}" || \
    echo -e "${RED}[ОШИБКА] ens20 не создан${NC}"

# Активация соединений
echo -e "${YELLOW}[INFO] Активация сетевых интерфейсов${NC}"
for conn in ens18 ens19 ens20; do
    if nmcli con up "$conn" &>> "$LOG_FILE"; then
        echo -e "${GREEN}[УСПЕХ] Интерфейс $conn активирован${NC}"
    else
        echo -e "${RED}[ОШИБКА] Не удалось активировать $conn${NC}"
    fi
done

# Настройка firewalld
echo -e "${YELLOW}[INFO] Запуск firewalld${NC}"
systemctl enable --now firewalld && echo -e "${GREEN}[УСПЕХ] firewalld запущен${NC}" || \
    { echo -e "${RED}[ОШИБКА] Не удалось запустить firewalld${NC}"; exit 1; }

firewall-cmd --zone=external --change-interface=ens18 --permanent && \
    echo -e "${GREEN}[УСПЕХ] ens18 назначен в external${NC}" || \
    echo -e "${RED}[ОШИБКА] Не удалось назначить ens18${NC}"

for int in ens19 ens20; do
    firewall-cmd --zone=internal --change-interface=$int --permanent && \
        echo -e "${GREEN}[УСПЕХ] $int назначен в internal${NC}" || \
        echo -e "${RED}[ОШИБКА] Не удалось назначить $int${NC}"
done

firewall-cmd --zone=internal --add-forward --permanent && \
    echo -e "${GREEN}[УСПЕХ] Включён форвардинг в internal${NC}" || \
    echo -e "${RED}[ОШИБКА] Не удалось включить форвардинг${NC}"

firewall-cmd --reload && \
    echo -e "${GREEN}[УСПЕХ] firewalld перезагружен${NC}" || \
    echo -e "${RED}[ОШИБКА] Не удалось перезагрузить firewalld${NC}"

echo -e "${YELLOW}[INFO] Активные зоны firewalld:${NC}"
firewall-cmd --get-active-zones | tee -a "$LOG_FILE"

# Настройка sysctl
echo -e "${YELLOW}[INFO] Настройка sysctl.conf${NC}"
[ -f "$SYSCTL_CONF" ] || { echo -e "${RED}[ОШИБКА] $SYSCTL_CONF не найден${NC}"; exit 1; }

cp "$SYSCTL_CONF" "${SYSCTL_CONF}.bak" && echo -e "${GREEN}[УСПЕХ] Бэкап sysctl.conf создан${NC}" || \
    { echo -e "${RED}[ОШИБКА] Не удалось создать бэкап${NC}"; exit 1; }

sed -i 's/net.ipv4.ip_forward *= *0/net.ipv4.ip_forward = 1/' "$SYSCTL_CONF" && \
    echo -e "${GREEN}[УСПЕХ] Включен IP forwarding${NC}" || \
    echo -e "${RED}[ОШИБКА] Не удалось включить IP forwarding${NC}"

sed -i 's/net.ipv4.conf.default.rp_filter *= *1/net.ipv4.conf.default.rp_filter = 0/' "$SYSCTL_CONF" && \
    echo -e "${GREEN}[УСПЕХ] Отключён rp_filter${NC}" || \
    echo -e "${RED}[ОШИБКА] Не удалось изменить rp_filter${NC}"

sysctl -p "$SYSCTL_CONF" &>> "$LOG_FILE" && \
    echo -e "${GREEN}[УСПЕХ] Параметры sysctl применены${NC}" || \
    echo -e "${RED}[ОШИБКА] Не удалось применить параметры sysctl${NC}"

# Установка часового пояса
echo -e "${YELLOW}[INFO] Установка часового пояса: $TIMEZONE${NC}"
timedatectl set-timezone "$TIMEZONE" && \
    echo -e "${GREEN}[УСПЕХ] Часовой пояс установлен${NC}" || \
    echo -e "${RED}[ОШИБКА] Не удалось установить часовой пояс${NC}"

# Завершение
echo -e "${YELLOW}[INFO] Скрипт завершён. Лог сохранён в $LOG_FILE${NC}"
read -p "Перезагрузить систему сейчас? (y/n): " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[INFO] Перезагрузка...${NC}"
    reboot
else
    echo -e "${YELLOW}[INFO] Перезагрузка отменена пользователем${NC}"
fi
