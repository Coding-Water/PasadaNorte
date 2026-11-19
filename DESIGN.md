# PasadaNorte Design Direction (`DESIGN.md`)

This document defines the visual identity, design tokens, liveliness dials, and antislop guardrails for **PasadaNorte** across both:
- **`mobile_client`** (Flutter Mobile App for Laoag City Commuters & Tricycle Drivers)
- **`web_client`** (Flutter Web Command Center for MINC & TODA Administrators)

---

## 1. Brand Identity & Purpose

- **Product:** Laoag City Paratransit Dispatch, Digital Pila Queue, and Municipal Fare Regulation Platform (Ordinance 2023-005).
- **Character:** Civic, trustworthy, high-legibility outdoor/sunlight-ready transit tool. Not a generic "AI startup" or a clone of SaaS tools like Krisp or Linear.
- **Identity Motif:** **Laoag Emerald + Transit Pill & Pila Rank Badge** — crisp high-contrast emerald (`#007A37`) paired with deep charcoal slate (`#0F172A` / `#212121`), clean 1px structural borders (`#E2E8F0`), and tabular/monospace-free numeric clarity for fares (`PHP`), distances (`km`), and queue ranks (`#1`, `#2`).

---

## 2. Liveliness Dials (`antislop` Part 3)

### Mobile Client (`mobile_client`)
- **Dial:** `ENERGY 2 / RHYTHM 2 / MOTION 1`
- **Design Read:** *Reading this as: civic paratransit utility app for Laoag City commuters and tricycle drivers, in a high-contrast sunlight-legible transit style, dial ENERGY 2 / RHYTHM 2 / MOTION 1.*
- **Focal Point:** One primary action per screen (e.g., "Where are you going?" booking bar on Rider Home; Duty/Queue status on Driver Map; Fare total on Checkout).

### Web Command Center (`web_client`)
- **Dial:** `ENERGY 1 / RHYTHM 2 / MOTION 1`
- **Design Read:** *Reading this as: municipal dispatch and compliance command center for MINC and TODA administrators, in a structured operational console style, dial ENERGY 1 / RHYTHM 2 / MOTION 1.*
- **Focal Point:** Live operational map / active queue / SOS sentinel at the top of each view, with secondary tables and logs clearly subordinated.

---

## 3. Unified Color System (R-25, R-29)

Limit active brand colors to **2 core colors + 1 accent** plus neutral surfaces and strict semantic status tokens. Every text-on-background pairing **must** pass WCAG AA (4.5:1 normal text, 3.0:1 large text / UI icons).

### Core & Accent Tokens
| Token | Hex | Role & Contrast Verification |
| :--- | :--- | :--- |
| `brandEmerald` (Primary) | `#007A37` | Primary buttons, active nav, brand markers. White `#FFFFFF` text on `#007A37` = **5.47:1 (PASS AA)**. |
| `brandEmeraldDeep` | `#065F46` | Hover/pressed primary, text on mint pills (`#E8F8EF`). |
| `brandMintSurface` | `#E8F8EF` | Soft status/location pill fill (paired only with `#065F46` or `#007A37` text). |
| `inkPrimary` | `#0F172A` | Primary headings and body text on light surfaces (**17.85:1** on `#FFFFFF`). |
| `inkSecondary` | `#475569` | Secondary labels, subtitles, table headers (**7.58:1** on `#FFFFFF`). |
| `inkMuted` | `#64748B` | Captions, inactive bottom-nav labels, placeholders (**4.76:1** on `#FFFFFF` — replaces `#BDBDBD` and `#94A3B8`). |
| `surfaceCanvas` | `#F8FAFC` | Unified app/dashboard canvas background (replaces mixed `#F8F9FA` / `#F8FAFC`). |
| `surfaceCard` | `#FFFFFF` | Cards, sheets, dialogs, sidebar. |
| `borderSubtle` | `#E2E8F0` | 1px structural dividers and card outlines. |
| `accentAmber` (Accent) | `#B45309` (text) / `#FEF3C7` (fill) | Pending review, warning badges, driver ratings (never raw `#F59E0B` text on white, which fails at 2.15:1). |

### Semantic Status Tokens (Replace 65 Ad-Hoc Hex Values)
- **Success / Approved / Online:** `#007A37` text on `#E8F8EF` fill (or `#FFFFFF` on `#007A37`)
- **Warning / Pending / Grace Period:** `#92400E` text on `#FEF3C7` fill
- **Danger / SOS / Rejected / Offline:** `#B91C1C` text on `#FEE2E2` fill (solid `#DC2626` with `#FFFFFF` text = **4.83:1 PASS**)
- **Info / GPS / Dispatch Route:** `#0369A1` text on `#E0F2FE` fill

**Banned:** `#00C466` with white text (2.31:1 FAIL), `#059669` with white text for normal labels (3.77:1 FAIL), `#BDBDBD` / `#94A3B8` for readable text, and unsystematized purples (`#7E22CE`, `#8B5CF6`).

---

## 4. Typography System (R-06)

- **Decision:** Use **Plus Jakarta Sans** (or **Roboto** / system sans if offline-bundled) consistently via `ThemeData.fontFamily` in both `mobile_client` and `web_client`, removing orphaned `fontFamily: 'Inter'` declarations.
- **Reason:** Geometric-humanist sans-serif provides high legibility at small mobile sizes (fare breakdowns, plate numbers, TODA names) and clean tabular alignment in web admin tables without looking like an AI terminal default.
- **Scale:**
  - Page / Screen Title: `20–24px`, `w800`, `letterSpacing: -0.3`
  - Section Header: `16–18px`, `w700`
  - Body / Table Cell: `14px`, `w500`
  - Caption / Badge: `12px`, `w600` (avoid extreme uppercase tracking)

---

## 5. Layout, Radius & Elevation Hierarchy (R-03, R-05, R-11, R-12)

- **Border Radius Scale:**
  - `8px`: Compact badges, status pills, table chips
  - `12px`: Inputs, inner list rows, map control buttons
  - `16px`: Standard cards, modals, dialogs
  - `24px`: Bottom sheets, primary pill CTAs (`mobile_client` only)
- **Elevation (2-Level Rule):**
  - **Level 0 (Flat + 1px `#E2E8F0` border):** All standard cards, lists, sidebar, and tables.
  - **Level 1 (`BoxShadow` blur 16, `black` 10% alpha):** Only floating map overlays (SOS button, active trip bottom sheet, search pill) so they lift cleanly above map tiles.
- **Web Responsive Breakpoint (`web_client`):**
  - `>= 1024px`: Persistent `260px` left navigation rail/sidebar.
  - `< 1024px`: Collapse sidebar into a `Drawer` triggered from an `AppBar` menu button so narrow viewports and tablets never overflow horizontally.

---

## 6. Recommended Fixes Prioritized

1. **Fix Contrast & Unify Palette (`HIGH`):** Replace `#00C466`, `#059669` (with white text), `#BDBDBD`, and `#94A3B8` with `brandEmerald` (`#007A37`) and `inkMuted` (`#64748B`), and extract a shared `WebTheme` / `AppTheme` token file so `web_client` stops using 65 inline hex colors.
2. **Eliminate Em Dashes (`HIGH`):** Replace all `—` characters in `web_client` (`index.html`, `main.dart`) and `mobile_client` (`driver_account_screen.dart`, `passenger_account_screen.dart`) with `-`, `:`, or commas.
3. **Make `web_client` Responsive & Accessible (`HIGH`):** Add a `< 1024px` `Drawer` breakpoint for the sidebar, add `lang="en"` to `web/index.html`, and add `Semantics` labels to custom clickable cards, map controls, and icon-only buttons.
4. **Fix Onboarding CTAs & Buzzwords (`LOW`):** Replace `"Let's Get Started"` with `"Create Account"` / `"Continue"`, and remove `"Seamless Transactions"`.
5. **Night-Shift Driver Dark Mode (`LOW`):** Add `darkTheme` in `AppTheme` (high-contrast `#0B1220` slate canvas + `#16A34A` / `#22C55E` with dark text) and a working light/dark toggle for drivers operating at night.
6. **Modularize `web_client/lib/main.dart` (Engineering Hygiene):** Split the 12,528-line single file into feature modules (`auth/`, `monitoring/`, `toda_pilas/`, `heatmap/`, `applications/`, `theme/`) matching `mobile_client`'s clean architecture.
