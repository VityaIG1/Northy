import Foundation
import Observation
import SwiftUI

// MARK: - Instant In-App Language Switcher (@Observable)

public enum AppLanguageOption: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case russian = "ru"
    case english = "en"

    public var id: String { rawValue }

    public var titleKey: String {
        switch self {
        case .system:
            return "language.system"
        case .russian:
            return "language.russian"
        case .english:
            return "language.english"
        }
    }

    public var resolvedLanguageCode: String {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.lowercased().hasPrefix("ru") ? "ru" : "en"
        case .russian:
            return "ru"
        case .english:
            return "en"
        }
    }

    public var resolvedLocale: Locale {
        Locale(identifier: resolvedLanguageCode)
    }
}

@Observable
@MainActor
public final class LocalizationManager {

    public var selectedOption: AppLanguageOption {
        didSet {
            SharedTunnelStore.shared.saveLanguageCode(selectedOption.rawValue)
            rebuildBundle()
        }
    }

    private(set) var activeBundle: Bundle = .main

    public var activeLocale: Locale {
        selectedOption.resolvedLocale
    }

    public init() {
        let savedRaw = SharedTunnelStore.shared.loadLanguageCode()
        self.selectedOption = AppLanguageOption(rawValue: savedRaw) ?? .system
        rebuildBundle()
    }

    /// Resolves localized string from `.xcstrings` bundle immediately without app restart.
    public func tr(_ key: String) -> String {
        let value = activeBundle.localizedString(forKey: key, value: nil, table: "Localizable")
        if value != key {
            return value
        }
        return Self.fallbackCatalog[selectedOption.resolvedLanguageCode]?[key]
            ?? Self.fallbackCatalog["en"]?[key]
            ?? key
    }

    private func rebuildBundle() {
        let code = selectedOption.resolvedLanguageCode
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            activeBundle = bundle
        } else {
            activeBundle = .main
        }
    }

    // Complete in-memory mirror of Localizable.xcstrings so Previews and instant language switching never miss a key
    private static let fallbackCatalog: [String: [String: String]] = [
        "en": [
            "app.title": "NOTHING // VPN",
            "tab.servers": "SERVERS",
            "tab.settings": "SETTINGS",
            "status.connected": "TUNNEL ACTIVE",
            "status.connecting": "ESTABLISHING LINK...",
            "status.disconnected": "STANDBY // OFFLINE",
            "action.connect": "ENGAGE TUNNEL",
            "action.disconnect": "TERMINATE LINK",
            "paste.button": "PASTE TO CONNECT",
            "paste.subtitle": "VLESS · VMESS · TROJAN · SS · SUBSCRIPTION",
            "servers.section.nodes": "CONFIGURED NODES",
            "servers.ping.all": "PING MATRIX",
            "telemetry.down": "DOWNLOADED",
            "telemetry.up": "UPLOADED",
            "telemetry.uptime": "SESSION UPTIME",
            "telemetry.speed.down": "DL SPEED",
            "telemetry.speed.up": "UL SPEED",
            "telemetry.total": "TOTAL SESSION",

            // Ping Settings (Happ Parity)
            "settings.ping.header": "PING & LATENCY DIAGNOSTICS",
            "ping.method.header": "PING TYPE",
            "ping.method.tcp": "TCP SYN",
            "ping.method.urltest": "VIA PROXY (204)",
            "ping.method.icmp": "ICMP ECHO",
            "ping.url.header": "PING TEST URL (HTTP 204)",
            "ping.timeout.header": "PING TIMEOUT (SEC)",
            "ping.display.header": "RESULT DISPLAY FORMAT",
            "ping.display.ms": "MS + SIGNAL BARS",
            "ping.display.bars": "SIGNAL BARS ONLY",
            "ping.sort": "SORT NODES BY LOWEST PING",
            "ping.autostart": "AUTO-PING ON APP LAUNCH",

            // Connection & Core Settings (Happ Parity)
            "settings.connection.header": "CONNECTION & XRAY CORE",
            "connection.mode.header": "TUNNEL EXECUTION MODE",
            "connection.mode.tun": "TUN // SYSTEM L3 INTERFACE",
            "connection.mode.proxy": "PROXY ONLY // SOCKS5+HTTP (10808)",
            "connection.sniffing": "TRAFFIC SNIFFING (HTTP/TLS/QUIC)",
            "connection.sniff.override": "OVERRIDE DESTINATION BY SNIFFED HOST",
            "connection.mux": "MUX TCP MULTIPLEXING (CONCURRENCY 8)",
            "connection.fragment": "TLS HELLO FRAGMENTATION (DPI BYPASS)",
            "connection.fragment.preset": "FRAGMENT PACKET WINDOW",
            "connection.tfo": "TCP FAST OPEN (TFO)",
            "connection.allowinsecure": "ALLOW INSECURE TLS CERTIFICATES",
            "connection.ondemand": "CONNECT ON DEMAND (AUTO-RECONNECT)",
            "connection.disconnectsleep": "DISCONNECT TUNNEL ON DEVICE SLEEP",
            "connection.mtu": "TUN INTERFACE MTU",
            "connection.domainstrategy": "XRAY DOMAIN STRATEGY",
            "connection.loglevel": "CORE LOG LEVEL",
            "connection.corejson.preview": "INSPECT GENERATED XRAY-CORE JSON",

            // Routing & DNS
            "settings.routing.header": "ROUTING & SPLIT TUNNELING",
            "routing.mode.global": "GLOBAL TUNNEL",
            "routing.mode.global.desc": "Route 100% of IPv4/IPv6 packets through active Xray core",
            "routing.mode.split": "SPLIT TUNNEL // BYPASS LAN & REGIONAL",
            "routing.mode.split.desc": "Direct routing for private subnets and regional (.ru/.рф) domains",
            "routing.mode.direct": "DIRECT DIAGNOSTIC",
            "routing.mode.direct.desc": "Keep DNS encryption active without proxying TCP/UDP payload",
            "settings.dns.header": "DNS OVER HTTPS RESOLVER",
            "settings.killswitch": "STRICT KILL SWITCH (INCLUDE ALL NETWORKS)",
            "settings.ipv6": "IPV6 TUNNEL ROUTING",

            // Subscriptions
            "settings.subscriptions.header": "SUBSCRIPTIONS & AUTO-UPDATE",
            "settings.subscriptions.empty": "NO ACTIVE SUBSCRIPTIONS // PASTE HTTPS LINK ON SERVERS TAB",
            "subscription.autoupdate": "AUTO-UPDATE SUBSCRIPTIONS ON LAUNCH",
            "subscription.pingafter": "AUTO-PING NODES AFTER SYNC",
            "subscription.useragent": "SUBSCRIPTION HTTP USER-AGENT",
            "subscription.syncall": "SYNC ALL",

            // Language
            "settings.language.header": "INTERFACE LANGUAGE",
            "language.system": "SYSTEM",
            "language.english": "ENGLISH",
            "language.russian": "РУССКИЙ",

            // Appearance & Themes
            "settings.appearance.header": "APPEARANCE & THEME",
            "settings.appearance.rounded_corners": "ROUNDED CORNERS",
            "settings.appearance.rounded_corners_desc": "Applied to UI containers, cards and buttons. Matrix glyphs preserve dot geometry.",
            "settings.appearance.accent_color": "ACCENT THEME // COLOR PICKER",
            "settings.appearance.accent_red": "NOTHING RED",
            "settings.appearance.accent_white": "ELECTRIC WHITE",
            "settings.appearance.accent_amber": "CYBER AMBER",
            "settings.appearance.accent_cyan": "MATRIX CYAN",
            "settings.appearance.accent_gray": "STEALTH GRAY",

            // Routing CIDRs
            "settings.routing.cidrs.header": "CUSTOM BYPASS SUBNETS (CIDR)",

            // Support Authors
            "settings.support.header": "SUPPORT AUTHORS",
            "settings.support.scrt_role": "Idea Author & Concept",
            "settings.support.vitya_role": "Application Developer & Architect"
        ],
        "ru": [
            "app.title": "NOTHING // VPN",
            "tab.servers": "СЕРВЕРЫ",
            "tab.settings": "НАСТРОЙКИ",
            "status.connected": "ТУННЕЛЬ АКТИВЕН",
            "status.connecting": "УСТАНОВКА СВЯЗИ...",
            "status.disconnected": "ОЖИДАНИЕ // ОФЛАЙН",
            "action.connect": "ВКЛЮЧИТЬ VPN",
            "action.disconnect": "ОТКЛЮЧИТЬ VPN",
            "paste.button": "ВСТАВИТЬ И ПОДКЛЮЧИТЬ",
            "paste.subtitle": "VLESS · VMESS · TROJAN · SS · ПОДПИСКА",
            "servers.section.nodes": "ДОБАВЛЕННЫЕ СЕРВЕРЫ",
            "servers.ping.all": "ПРОВЕРИТЬ ПИНГ",
            "telemetry.down": "ЗАГРУЖЕНО",
            "telemetry.up": "ОТПРАВЛЕНО",
            "telemetry.uptime": "ВРЕМЯ СЕССИИ",
            "telemetry.speed.down": "СКОРОСТЬ ↓",
            "telemetry.speed.up": "СКОРОСТЬ ↑",
            "telemetry.total": "ВСЕГО ОБЪЕМ",

            // Ping Settings (Happ Parity)
            "settings.ping.header": "НАСТРОЙКИ ПИНГА И ЗАДЕРЖКИ",
            "ping.method.header": "ТИП ПРОВЕРКИ ПИНГА",
            "ping.method.tcp": "TCP SYN",
            "ping.method.urltest": "ЧЕРЕЗ ПРОКСИ (204)",
            "ping.method.icmp": "ICMP ECHO",
            "ping.url.header": "URL ПРОВЕРКИ СОЕДИНЕНИЯ (HTTP 204)",
            "ping.timeout.header": "ТАЙМАУТ ПИНГА (СЕК)",
            "ping.display.header": "ФОРМАТ ОТОБРАЖЕНИЯ ПИНГА",
            "ping.display.ms": "МС + ШКАЛА СИГНАЛА",
            "ping.display.bars": "ТОЛЬКО ШКАЛА СИГНАЛА",
            "ping.sort": "СОРТИРОВАТЬ СЕРВЕРЫ ПО МИН. ПИНГУ",
            "ping.autostart": "АВТО-ПИНГ ПРИ ЗАПУСКЕ ПРИЛОЖЕНИЯ",

            // Connection & Core Settings (Happ Parity)
            "settings.connection.header": "НАСТРОЙКИ СОЕДИНЕНИЯ И ЯДРА XRAY",
            "connection.mode.header": "РЕЖИМ РАБОТЫ ТУННЕЛЯ",
            "connection.mode.tun": "TUN // СИСТЕМНЫЙ СЕТЕВОЙ ИНТЕРФЕЙС",
            "connection.mode.proxy": "ТОЛЬКО ПРОКСИ // SOCKS5+HTTP (10808)",
            "connection.sniffing": "SNIFFING АНАЛИЗ ТРАФИКА (HTTP/TLS/QUIC)",
            "connection.sniff.override": "ПОДМЕНА ЦЕЛИ ПО ДОМЕНУ SNIFFING",
            "connection.mux": "MUX МУЛЬТИПЛЕКСИРОВАНИЕ (8 ПОТОКОВ)",
            "connection.fragment": "ФРАГМЕНТАЦИЯ TLS HELLO (ОБХОД DPI)",
            "connection.fragment.preset": "ПАРАМЕТРЫ ФРАГМЕНТАЦИИ ПАКЕТОВ",
            "connection.tfo": "TCP FAST OPEN (TFO)",
            "connection.allowinsecure": "РАЗРЕШИТЬ НЕВАЛИДНЫЕ TLS СЕРТИФИКАТЫ",
            "connection.ondemand": "CONNECT ON DEMAND (АВТОПЕРЕПОДКЛЮЧЕНИЕ)",
            "connection.disconnectsleep": "ОТКЛЮЧАТЬ ТУННЕЛЬ В РЕЖИМЕ СНА",
            "connection.mtu": "РАЗМЕР ПАКЕТА MTU (TUN)",
            "connection.domainstrategy": "СТРАТЕГИЯ ДОМЕНОВ XRAY",
            "connection.loglevel": "УРОВЕНЬ ЛОГИРОВАНИЯ ЯДРА",
            "connection.corejson.preview": "ПРОСМОТР СГЕНЕРИРОВАННОГО XRAY JSON",

            // Routing & DNS
            "settings.routing.header": "МАРШРУТИЗАЦИЯ И ТУННЕЛИРОВАНИЕ",
            "routing.mode.global": "ВЕСЬ ТРАФИК",
            "routing.mode.global.desc": "Направлять весь трафик устройства через защищенный туннель",
            "routing.mode.split": "РАЗДЕЛЬНОЕ // ОБХОД LAN И RU",
            "routing.mode.split.desc": "Прямой доступ для локальной сети и региональных (.ru/.рф) доменов",
            "routing.mode.direct": "ПРЯМОЕ СОЕДИНЕНИЕ",
            "routing.mode.direct.desc": "Только защищенный DNS без проксирования трафика",
            "settings.dns.header": "DNS-СЕРВЕР (DOH)",
            "settings.killswitch": "KILL SWITCH (БЛОКИРОВКА ТРАФИКА ВНЕ VPN)",
            "settings.ipv6": "МАРШРУТИЗАЦИЯ IPV6",

            // Subscriptions
            "settings.subscriptions.header": "ПОДПИСКИ И АВТООБНОВЛЕНИЕ",
            "settings.subscriptions.empty": "НЕТ ПОДПИСОК // ВСТАВЬТЕ ССЫЛКУ НА ЭКРАНЕ СЕРВЕРОВ",
            "subscription.autoupdate": "АВТООБНОВЛЕНИЕ ПОДПИСОК ПРИ ВХОДЕ",
            "subscription.pingafter": "АВТО-ПИНГ ПОСЛЕ ОБНОВЛЕНИЯ ПОДПИСКИ",
            "subscription.useragent": "ЗАГОЛОВОК USER-AGENT ДЛЯ ПОДПИСОК",
            "subscription.syncall": "ОБНОВИТЬ ВСЕ",

            // Language
            "settings.language.header": "ЯЗЫК ИНТЕРФЕЙСА",
            "language.system": "СИСТЕМНЫЙ",
            "language.english": "ENGLISH",
            "language.russian": "РУССКИЙ",

            // Appearance & Themes
            "settings.appearance.header": "ВНЕШНИЙ ВИД И ТЕМА",
            "settings.appearance.rounded_corners": "СКРУГЛЕННЫЕ КРАЯ",
            "settings.appearance.rounded_corners_desc": "Применяется к карточкам, кнопкам и полям ввода. Матричные глифы сохраняют геометрию.",
            "settings.appearance.accent_color": "ТЕМА АКЦЕНТА // ВЫБОР ЦВЕТА",
            "settings.appearance.accent_red": "NOTHING КРАСНЫЙ",
            "settings.appearance.accent_white": "БЕЛЫЙ",
            "settings.appearance.accent_amber": "ЯНТАРНЫЙ",
            "settings.appearance.accent_cyan": "НЕОНОВЫЙ ЦИАН",
            "settings.appearance.accent_gray": "СЕРЫЙ",

            // Routing CIDRs
            "settings.routing.cidrs.header": "СПИСОК ИСКЛЮЧЕНИЙ ПОДСЕТЕЙ (CIDR)",

            // Support Authors
            "settings.support.header": "ПОДДЕРЖКА АВТОРОВ",
            "settings.support.scrt_role": "Автор идеи и концепта",
            "settings.support.vitya_role": "Разработчик приложения"
        ]
    ]
}
