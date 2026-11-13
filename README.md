# Northy (iOS Native Client)

Нативный VPN-клиент для iOS в индустриальной эстетике **Nothing OS** с архитектурой **Happ** (`NEPacketTunnelProvider`, Xray/Sing-box Core, VLESS REALITY, VMess, Trojan, Shadowsocks).

**Идентификаторы:**
- **Имя приложения:** `Northy`
- **Bundle ID:** `com.scrt.north`
- **Extension ID:** `com.scrt.north.PacketTunnel`
- **App Group:** `group.com.scrt.north`
- **Team ID:** `NORTHVPN99`
- **Версия:** `0.2.0 (Build 2)`

## Особенности

- **Эстетика Nothing OS:** монохромная палитра, 5×7 Dot-Matrix типографика, круговой Glyph-радар, механические переключатели.
- **Подключение в один клик (Paste-to-Connect):** автопарсинг ссылок `vless://`, `vmess://`, `trojan://`, `ss://` и Base64-подписок из буфера обмена.
- **Телеметрия в реальном времени:** таймер сессии (`00:00:00`), скорость загрузки/отдачи (`KB/S`, `MB/S`) и суммарный объем данных.
- **Диагностика пинга:** многопоточный TCP SYN / HTTP 204 URLTest с авто-сортировкой серверов.
- **Раздельное туннелирование и безопасность:** обход локальных сетей (LAN) и региональных доменов (`.ru`, `.рф`), DoH DNS, Kill Switch, фрагментация TLS Hello (обход DPI).
- **Мгновенная локализация:** String Catalogs (`.xcstrings`) с переключением языков без перезапуска приложения (Русский / English / Системный).
- **Сразу подписанный IPA (Auto-Signing):** автоматическая генерация сертификата, подпись Entitlements (включая NetworkExtension) и создание валидного `embedded.mobileprovision` без необходимости ручной настройки профилей.

---

## Автоматическая сборка IPA через GitHub Actions

В репозитории настроен автоматический CI/CD воркфлоу (`.github/workflows/build-ipa.yml`), который компилирует и сразу подписывает `.ipa` на macOS-раннерах GitHub.

### Быстрый старт:

1. **Инициализируйте Git и сделайте коммит:**
   ```bash
   git init
   git add .
   git commit -m "feat: Northy iOS client with auto-signed IPA workflow"
   ```

2. **Привяжите ваш репозиторий на GitHub и отправьте код:**
   ```bash
   git branch -M main
   git remote add origin https://github.com/ВАШ_ЛОГИН/ИМЯ_РЕПОЗИТОРИЯ.git
   git push -u origin main
   ```

3. **Сборка и скачивание подписанного IPA:**
   - Перейдите во вкладку **Actions** в репозитории на GitHub.
   - Выберите воркфлоу **Build Northy IPA** (запускается автоматически при пуше или кнопкой **Run workflow**).
   - По завершении сборки скачайте готовый подписанный архив в секции **Artifacts** (`Northy-v0.2.0-signed-ipa`).

### Установка на устройство:
- **TrollStore:** Устанавливает напрямую без переподписи, сохраняя все entitlements туннеля.
- **AltStore / Sideloadly / Scarlet:** Откройте скачанный `.ipa` — они автоматически переподпишут его вашим личным Apple ID и установят на iPhone.

---

## Локальная сборка на Mac

В терминале на macOS выполните:

```bash
chmod +x scripts/build_ipa.sh
./scripts/build_ipa.sh
```

Готовый файл появится в `build/Northy-v0.2.0-signed.ipa` и `build/Northy.ipa`.
