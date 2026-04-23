# faesslich_pedmanager

A server-authoritative ped selection system for FiveM with a modern React-based NUI. Players with granted access can browse a catalog of human and animal peds, save them to a personal collection, pick a default that loads automatically on spawn, and apply any owned ped at any time.

The resource is framework-agnostic by design: it detects and supports **ESX Legacy** and **QBCore** out of the box, and integrates with most common notification systems automatically.

---

## Features

- **React NUI** with search, tabs (My Peds / All Peds), category filter (humans / animals), and per-card action buttons
- **Personal ped library** per player, persisted in MySQL
- **Default ped** that loads automatically when the player spawns
- **Access control**: only admins (configurable groups) or players explicitly granted via console commands can open the menu
- **Vanilla ped catalog** with ~700 stock GTA V peds included, plus an open slot for **custom streamed peds** (streamed models can be registered with an image URL and category)
- **Animal / human filter** at config level — hide either category globally
- **Server-authoritative model validation** — clients cannot apply a ped that isn't in the registered catalog
- **Rate limiting** on all mutating callbacks (1 req/sec per player) to prevent event spam
- **Adapter-based notifications**: auto-detects `ox_lib`, ESX, QBCore, `okokNotify`, `wasabi_notify`, `mythic_notify`, `pNotify`, `t-notify`, with a `custom` hook for anything else
- **Multi-language support** (English and German included; add more by dropping a `locales/xx.lua` file)
- **Clean shutdown**: the NUI closes and the player ped is reset when the resource stops

---

## Compatibility

| Component        | Supported                                                                 |
|------------------|---------------------------------------------------------------------------|
| FiveM artifact   | Recent cerulean builds (`fx_version 'cerulean'`, `lua54 'yes'`)           |
| Frameworks       | ESX Legacy, QBCore (auto-detected)                                        |
| Database         | MySQL via [`oxmysql`](https://github.com/overextended/oxmysql)           |
| UI library       | [`ox_lib`](https://github.com/overextended/ox_lib) (callbacks)           |
| Notifications    | ox_lib, ESX, QBCore, okokNotify, wasabi_notify, mythic_notify, pNotify, t-notify, or custom export |
| Skin reset       | `esx_skin` / `skinchanger` (ESX) or `qb-clothes` (QBCore)                |

---

## Dependencies

Required:

- [`ox_lib`](https://github.com/overextended/ox_lib)
- [`oxmysql`](https://github.com/overextended/oxmysql)
- Either `es_extended` (ESX Legacy) **or** `qb-core`

Optional (auto-detected):

- Any supported notification resource listed above
- `esx_skin` + `skinchanger` (ESX) or `qb-clothes` (QBCore) for the default-skin reset

---

## Installation

1. Clone or download the resource into your server's resources folder, inside an appropriate category (e.g. `resources/[custom]/faesslich_pedmanager`).
2. Install the NUI build artifacts. The repository ships with a prebuilt `web/dist/`, so no build step is required to run the resource. If you modify the UI, rebuild it:
   ```bash
   cd web
   pnpm install
   pnpm build
   ```
3. Ensure [`ox_lib`](https://github.com/overextended/ox_lib) and [`oxmysql`](https://github.com/overextended/oxmysql) are started **before** this resource.
4. Add to your `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure faesslich_pedmanager
   ```
5. Start the server once. The resource creates its own MySQL tables on first boot:
   - `faesslich_pedmanager` — per-player ped collection (identifier, ped model, is_default)
   - `faesslich_pedmanager_access` — identifiers that have been granted menu access

No manual SQL import is needed.

---

## Configuration

All configuration lives in `config/config.lua` and `config/peds.lua`.

### `config/config.lua`

| Option                   | Default             | Description                                                                                         |
|--------------------------|---------------------|-----------------------------------------------------------------------------------------------------|
| `Config.Language`        | `'en'`              | Active locale. Falls back to English for missing keys. Place translations in `locales/<lang>.lua`. |
| `Config.AdminGroups`     | `{ 'admin', 'god' }`| ESX groups / QBCore permissions that bypass the access list.                                        |
| `Config.Notification`    | `'auto'`            | Notification provider. `auto` detects one; otherwise force one of the supported providers.         |
| `Config.ShowAnimalPeds`  | `true`              | Show the animal (`a_c_*`) category in the UI and catalog.                                           |
| `Config.ShowHumanPeds`   | `true`              | Show the human category.                                                                            |
| `Config.Debug`           | `true`              | Enables verbose server/client prints via `DebugMessage`. Disable on production.                     |

### `config/peds.lua`

- `Config.VanillaPeds` — list of stock ped model names. The full GTA V roster is included; trim or extend to taste.
- `Config.CustomPeds` — map of custom (streamed) ped models to either an image URL or a table:
  ```lua
  Config.CustomPeds = {
      ["my_streamed_ped"]  = "https://cdn.example.com/ped.webp",
      ["my_streamed_dog"]  = { image = "https://cdn.example.com/dog.webp", category = "animal" },
  }
  ```
  Custom peds must be streamed separately by another resource. The category defaults based on the `a_c_` prefix if omitted.

### Custom notification provider

If you use a notification resource that isn't in the built-in list, set:

```lua
Config.Notification = 'custom'
Config.CustomNotification = {
    resource = 'my_notify_resource',
    export   = 'SendNotification', -- exports[resource][export](message, type, duration)
}
```

---

## Usage

### Opening the menu

Players run `/pedmanager` in-game. The menu only opens for:

- Players whose framework group matches `Config.AdminGroups`, **or**
- Players whose identifier exists in the `faesslich_pedmanager_access` table.

Everyone else receives a "no access" notification.

### Console commands (server console / rcon only)

| Command                                | Description                                 |
|----------------------------------------|---------------------------------------------|
| `pedmanager_grant <serverId>`          | Grant access to an online player by ID.     |
| `pedmanager_revoke <serverId>`         | Revoke access from an online player by ID.  |
| `pedmanager_grant_id <identifier>`     | Grant access by raw identifier (offline).   |
| `pedmanager_revoke_id <identifier>`    | Revoke access by raw identifier (offline).  |
| `pedmanager_list`                      | List all identifiers with access.           |

All commands are registered as restricted and will reject non-console callers.

### Default peds

Any ped in a player's collection can be flagged as the default via the menu. When the player spawns (or when the resource restarts with the player already in game), the default ped is applied automatically.

---

## Localization

Locale files live in `locales/` and use the standard `Locale['xx'] = { key = 'value', ... }` pattern. English is always loaded as a fallback, so a partial translation will still produce a working UI. To add a new language:

1. Copy `locales/en.lua` to `locales/<code>.lua`.
2. Translate the values.
3. Set `Config.Language = '<code>'` in `config/config.lua`.

The active locale and its fallback are sent to the NUI on open, so the React frontend stays in sync with the Lua side without additional wiring.

---

## Security notes

- All mutating callbacks re-check access and rate-limit per player source.
- The client never applies a ped the server hasn't validated against the catalog (`Config.PedLookup`).
- Console commands cannot be triggered from client source ids.
- The database access cache is cleared on `playerDropped` to avoid stale reads on identifier reuse.

---

## Development

NUI source is in `web/src/` (React + Vite + TypeScript + Tailwind). The Lua side exposes a single `setLocale` NUI message that delivers a merged `{ strings, language }` payload on every menu open.

Build commands:

```bash
cd web
pnpm install
pnpm build   # emits web/dist/
pnpm dev     # optional: browser dev server (no game-integration)
```

`fxmanifest.lua` ships only `web/dist/*.html` and `web/dist/assets/**` to the client; source files are not streamed.

---

## License

Released under the MIT License. See `LICENSE` if provided, otherwise the MIT terms apply by default.

---

## Credits

- Author: **Faesslich**
- Built on top of [`ox_lib`](https://github.com/overextended/ox_lib) and [`oxmysql`](https://github.com/overextended/oxmysql).
- Vanilla ped preview images are sourced from `https://docs.fivem.net/peds/`.

