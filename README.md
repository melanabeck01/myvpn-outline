# Outline VPN Server - Быстрое развертывание

Готовое решение для быстрого развертывания Outline VPN сервера на любом VPS с Ubuntu.

## 🚀 Рекомендуемая установка (ALL-IN-ONE)

### ⭐ Полная установка с оптимизацией и автозапуском
```bash
curl -sSL https://raw.githubusercontent.com/melanabeck01/myvpn-outline/main/install_complete.sh | bash
```
**Включает**: VPS оптимизация → Установка Outline → Автозапуск → Сохранение конфига

### 📋 Показать сохраненную конфигурацию для Outline Manager
```bash
curl -sSL https://raw.githubusercontent.com/melanabeck01/myvpn-outline/main/show_config.sh | bash
```

### 🔥 Исправить проблемы с подключением Outline Manager
```bash
curl -sSL https://raw.githubusercontent.com/melanabeck01/myvpn-outline/main/fix_firewall.sh | bash
```
**Использовать если**: Manager показывает ошибку подключения к серверу

---

## 🔧 Дополнительные утилиты

### Подключиться к VPS и установить Outline одной командой
```bash
./connect_vps.sh <IP> <USER> <PASSWORD>
```

### Техническая диагностика сервера
```bash
curl -sSL https://raw.githubusercontent.com/melanabeck01/myvpn-outline/main/get_outline_config.sh | bash
```

### Manual Docker Compose установка
```bash
# Установить Docker
apt update && apt install -y docker.io docker-compose

# Скачать конфигурацию
git clone https://github.com/melanabeck01/myvpn-outline.git
cd myvpn-outline

# Запустить сервер
docker-compose up -d
```

### Метод 3: Официальный установщик
```bash
curl -sSL https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh | bash
```

## 📋 Системные требования

- **OS**: Ubuntu 20.04+ (рекомендуется 24.04 LTS)
- **RAM**: Минимум 512MB (рекомендуется 1GB+)
- **CPU**: 1 vCore
- **Disk**: 10GB свободного места
- **Network**: Публичный IPv4 адрес

## 🔧 Управление сервером

### Docker Compose команды
```bash
cd /opt/outline-vpn

# Запуск сервисов
docker-compose up -d

# Остановка сервисов
docker-compose down

# Просмотр логов
docker-compose logs -f

# Перезапуск
docker-compose restart

# Обновление образов
docker-compose pull && docker-compose up -d
```

### Проверка статуса
```bash
# Статус контейнеров
docker ps

# Логи Outline сервера
docker logs outline-server

# Логи Watchtower (авто-обновления)
docker logs outline-watchtower
```

## 🌐 Настройка клиентов

1. **Скачать Outline Manager**: https://getoutline.org/
2. **Добавить сервер**: Вставить JSON конфигурацию из установки
3. **Создать ключи**: Нажать "+" для создания новых ключей доступа
4. **Подключить устройства**: Скачать Outline Client и импортировать ключи

### Поддерживаемые платформы клиентов
- **Windows**: Outline Client из Microsoft Store
- **macOS**: Outline Client из App Store  
- **iOS**: Outline Client из App Store
- **Android**: Outline Client из Google Play
- **Linux**: Outline Client AppImage

## 🔒 Безопасность

### Рекомендуемые настройки firewall
```bash
# Разрешить SSH
ufw allow ssh

# Разрешить Outline порты (адаптировать под ваши порты)
ufw allow 443/tcp
ufw allow 8080:8090/tcp
ufw allow 8080:8090/udp

# Включить firewall
ufw --force enable
```

### Порты по умолчанию
- **API Management**: Случайный порт (443-65535)
- **VPN Traffic**: Случайный порт (1024-65535) TCP/UDP

## 🔄 Резервное копирование

### Бэкап конфигурации
```bash
# Создать бэкап volumes
docker run --rm -v outline-data:/data -v $(pwd):/backup alpine tar czf /backup/outline-backup.tar.gz -C /data .

# Бэкап персистентного состояния
docker run --rm -v outline-persisted-state:/data -v $(pwd):/backup alpine tar czf /backup/outline-state-backup.tar.gz -C /data .
```

### Восстановление
```bash
# Восстановить данные
docker run --rm -v outline-data:/data -v $(pwd):/backup alpine tar xzf /backup/outline-backup.tar.gz -C /data
docker run --rm -v outline-persisted-state:/data -v $(pwd):/backup alpine tar xzf /backup/outline-state-backup.tar.gz -C /data

# Перезапустить сервисы
docker-compose restart
```

## 🛠️ Устранение неполадок

### Проблемы с подключением
1. Проверьте открытые порты: `netstat -tulpn`
2. Проверьте firewall: `ufw status`
3. Проверьте логи: `docker logs outline-server`

### Сервер не запускается
```bash
# Проверить статус Docker
systemctl status docker

# Проверить образы
docker images

# Пересоздать контейнеры
docker-compose down && docker-compose up -d --force-recreate
```

### Высокое использование ресурсов
```bash
# Мониторинг ресурсов
docker stats

# Ограничить ресурсы в docker-compose.yml
services:
  outline-server:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
```

## 📊 Мониторинг

### Метрики сервера
```bash
# Использование ресурсов
htop

# Сетевой трафик
iftop

# Статистика Docker
docker system df
```

## ⚡ Производительность

### Оптимизация для высоких нагрузок
```bash
# Увеличить лимиты файловых дескрипторов
echo "fs.file-max = 65536" >> /etc/sysctl.conf

# Оптимизация сети
echo "net.core.rmem_max = 16777216" >> /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" >> /etc/sysctl.conf

# Применить настройки
sysctl -p
```

## 📝 Changelog

- **v1.0**: Базовая конфигурация с Docker Compose
- **v1.1**: Добавлен автоматический установщик
- **v1.2**: Улучшены инструкции по безопасности

## 🤝 Поддержка

- **Документация Outline**: https://getoutline.org/
- **GitHub Issues**: Создайте issue в этом репозитории
- **Telegram**: @your_support_channel