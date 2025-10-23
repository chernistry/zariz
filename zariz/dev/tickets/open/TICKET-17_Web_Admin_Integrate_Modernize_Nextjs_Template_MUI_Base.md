Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

# [TICKET-17] Web Admin — Integrate Modernize Next.js Free (MUI) as Base Admin UI

Goal
- Replace the current minimal web-admin UI with a clean Modernize Next.js (MUI)–based admin shell that fits Zariz’s scope: orders, couriers availability, and users management (stores/couriers). Keep our auth/SSE/data contracts; remove template noise.

References
- Template: https://github.com/adminmart/Modernize-Nextjs-Free
- Current app: `zariz/web-admin`
- Contracts and practices: `zariz/dev/tech_task.md`, `zariz/dev/best_practices.md`

Scope
1) Adopt Modernize layout/theme (MUI) for header/sidebar/content shell
2) Port existing pages (login, orders list/detail) to new layout
3) Keep our `libs/api.ts`, `libs/sse.ts`, `libs/withAuth.tsx`; re-style forms/tables to MUI
4) Remove template demo pages/assets/routes not used by Zariz

Plan
1. Dependencies (within `zariz/web-admin`)
   - Add MUI & Emotion & Icons:
     - `yarn add @mui/material @emotion/react @emotion/styled @mui/icons-material @mui/lab`
     - Ensure `typescript`, `@types/node`, `@types/react` present (already)
2. Bring template layout/theme
   - Either clone template next to repo and copy, or fetch selected folders:
     - Copy `src/theme`, `src/layouts`, `src/components` (only shell/layout primitives, not app-specific demo widgets)
     - If template uses `src/` convention, place our app under `src/` too:
       - Move `pages` → `src/pages`, `components` → `src/components`, `libs` → `src/libs`, update imports
     - Keep `_app.tsx` and `_document.tsx` from template as base; inject our `withAuth` guard in pages
3. Clean up
   - Remove template sample pages (dashboards, ecommerce, charts not in scope)
   - Keep a single “Dashboard” route as redirect to Orders list
   - Ensure no analytics/telemetry packages except what’s approved (no secrets in logs)
4. Port Zariz pages to MUI
   - Login: MUI TextField/Select/Button; save JWT in localStorage
   - Orders list/detail: use MUI Table, TableToolbar with filters; Action buttons as MUI Button/IconButton
   - CSV export: keep current logic; surface via MUI Button
   - SSE: keep `libs/sse.ts` and subscribe in pages with cleanup
5. Theming and styling
   - Create light theme aligned with Zariz brand (tech_task colors if any); respect RTL via `theme.direction` from user’s locale
   - Ensure global font consistent (system default OK)
6. Config
   - Update `next.config.js` and `tsconfig.json` if moving to `src/`
   - Keep `NEXT_PUBLIC_API_BASE` usage
7. Access control
   - Keep `withAuth.tsx` HOC; add a role check where necessary (admin-only routes)

Verification
- `cd zariz/web-admin && yarn && yarn dev` → app loads with Modernize shell
- Navigate to `/orders` → list renders with filters and SSE updates
- Open order → detail renders with MUI components; Assign/Cancel buttons present
- Check auth redirect from `/` to `/login` when no token

Acceptance Criteria
- Modernize (MUI) layout active; no dead demo links or unused pages
- All Zariz flows remain functional (login, orders list/detail, SSE, CSV export)
- Lint/typecheck pass; dev server runs; visual fit & cleanliness consistent with best_practices

Notes
- This ticket lays the shell/foundation; domain pages are finalized in TICKET-20.
