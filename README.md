# Northy (iOS Native Client)

Нативный VPN-клиент для iOS в индустриальной эстетике **Nothing OS** с архитектурой **Happ** (`NEPacketTunnelProvider`, ядро Xray-core через встроенный [LibXray](https://github.com/XTLS/libxray), VLESS REALITY, VMess, Trojan, Shadowsocks).

**Идентификаторы:**
- **Имя приложения:** `Northy`
- **Bundle ID:** `com.scrt.north`
- **Extension ID:** `com.scrt.north.PacketTunnel`
- **App Group:** `group.com.scrt.north`
- **Team ID:** `NORTHVPN99`
- **Версия:** `0.4.0 (Build 4)`

## Особенности

- **Встроенное прокси-ядро:** Xray-core собирается в CI через CGo-мост `CGoInvoke` и статически линкуется в туннельное расширение; geoip/geosite-данные для правил обхода идут в комплекте.
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
   - По завершении сборки скачайте готовый подписанный архив в секции **Artifacts** (`Northy-signed-ipa`).

### Установка на устройство:
- **TrollStore:** Устанавливает напрямую без переподписи, сохраняя все entitlements туннеля.
- **AltStore / Sideloadly / Scarlet:** Откройте скачанный `.ipa` — они автоматически переподпишут его вашим личным Apple ID и установят на iPhone.

---

## Локальная сборка на Mac

Требуется: Xcode 15+, Go (`brew install go`) и Homebrew (XcodeGen ставится автоматически при первом запуске).

```bash
chmod +x scripts/build_libxray.sh scripts/build_ipa.sh
./scripts/build_libxray.sh   # собирает LibXray.xcframework + скачивает geoip/geosite.dat (~10-15 мин, кэшируется)
./scripts/build_ipa.sh       # генерирует проект (xcodegen), архивирует и подписывает
```

Готовый файл появится в `build/Northy-v<версия>-signed.ipa` и `build/Northy.ipa`.

Переменные окружения сборки ядра:

- `LIBXRAY_TAG` — тег [XTLS/libXray](https://github.com/XTLS/libxray) для сборки (по умолчанию `v26.10.31`);
- `FORCE_LIBXRAY_BUILD=1` — принудительная пересборка ядра даже при наличии кэша.
