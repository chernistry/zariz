# TICKET-01: Foundation - Clone Template and Remove Clerk Authentication

**READ FIRST:** `/Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md`

## Objective
Clone the `next-shadcn-dashboard-starter` template and remove Clerk authentication system, preparing the foundation for Zariz custom authentication.

## Context
The Zariz web-admin currently uses Next.js 12 with Material UI. We're migrating to Next.js 15 with shadcn/ui by cloning the Kiranism template and adapting it. The template uses Clerk for authentication, which must be removed and replaced with Zariz's JWT-based auth system.

## Reference Implementation
The octup dashboard successfully completed this migration. Key learnings:
- Removed all Clerk dependencies
- Kept the layout structure and UI components
- Implemented custom auth without breaking the dashboard layout

## Acceptance Criteria
- [x] Template cloned to `web-admin-v2` directory
- [x] All Clerk dependencies removed from package.json
- [x] Clerk middleware removed/replaced with placeholder
- [x] Clerk components removed from layout
- [x] App builds and runs without Clerk errors
- [x] Dashboard layout structure intact (sidebar, header, main content area)

## Implementation Steps

### 1. Clone Template
```bash
cd /Users/sasha/IdeaProjects/ios/zariz
git clone https://github.com/Kiranism/next-shadcn-dashboard-starter.git web-admin-v2
cd web-admin-v2
rm -rf .git
```

### 2. Remove Clerk Dependencies

**File: `package.json`**
Remove these dependencies:
```json
"@clerk/nextjs": "^6.12.12",
"@clerk/themes": "^2.2.26",
```

Run:
```bash
npm install
```

### 3. Remove Clerk Middleware

**File: `src/middleware.ts`**
Replace entire content with:
```typescript
import { NextRequest, NextResponse } from 'next/server';

export default function middleware(req: NextRequest) {
  // Placeholder - will implement auth check in TICKET-02
  return NextResponse.next();
}

export const config = {
  matcher: [
    '/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)',
    '/(api|trpc)(.*)'
  ]
};
```

### 4. Update Root Layout

**File: `src/app/layout.tsx`**
Remove Clerk provider imports and usage:
```typescript
// Remove these imports:
// import { ClerkProvider } from '@clerk/nextjs'

// In the return statement, remove <ClerkProvider> wrapper
// Keep: ThemeProvider, Providers, Toaster, children
```

Updated layout structure:
```typescript
export default async function RootLayout({
  children
}: {
  children: React.ReactNode;
}) {
  const cookieStore = await cookies();
  const activeThemeValue = cookieStore.get('active_theme')?.value;
  const isScaled = activeThemeValue?.endsWith('-scaled');

  return (
    <html lang='en' suppressHydrationWarning>
      <head>
        {/* theme script */}
      </head>
      <body className={cn(/* ... */)}>
        <NextTopLoader color='var(--primary)' showSpinner={false} />
        <ThemeProvider
          attribute='class'
          defaultTheme='system'
          enableSystem
          disableTransitionOnChange
          enableColorScheme
        >
          <Providers activeThemeValue={activeThemeValue as string}>
            <Toaster />
            {children}
          </Providers>
        </ThemeProvider>
      </body>
    </html>
  );
}
```

### 5. Remove Clerk Auth Pages

Delete these directories:
```bash
rm -rf src/app/auth/sign-in
rm -rf src/app/auth/sign-up
```

Create placeholder login page:
**File: `src/app/auth/login/page.tsx`**
```typescript
export default function LoginPage() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="text-center">
        <h1 className="text-2xl font-bold">Zariz Admin Login</h1>
        <p className="text-muted-foreground mt-2">
          Authentication will be implemented in TICKET-02
        </p>
      </div>
    </div>
  );
}
```

### 6. Update Dashboard Layout

**File: `src/app/dashboard/layout.tsx`**
Remove any Clerk-specific user fetching. Keep the layout structure:
```typescript
import AppSidebar from '@/components/layout/app-sidebar';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Zariz Admin Dashboard',
  description: 'Courier order management system'
};

export default function DashboardLayout({
  children
}: {
  children: React.ReactNode;
}) {
  return (
    <>
      <AppSidebar />
      {children}
    </>
  );
}
```

### 7. Update Navigation Components

**File: `src/components/nav-user.tsx`**
Replace Clerk user data with placeholder:
```typescript
// Remove: import { useUser } from '@clerk/nextjs'
// Replace with placeholder user object:
const user = {
  name: 'Admin User',
  email: 'admin@zariz.local',
  avatar: null
};
```

### 8. Clean Up Unused Template Features

Remove these directories (not needed for Zariz):
```bash
rm -rf src/features/products
rm -rf src/features/kanban
rm -rf src/features/profile
rm -rf src/app/dashboard/product
rm -rf src/app/dashboard/kanban
rm -rf src/app/dashboard/profile
```

Keep:
- `src/components/ui/*` (all shadcn components)
- `src/components/layout/*` (sidebar, header, providers)
- `src/lib/*` (utilities)
- `src/hooks/*` (custom hooks)

### 9. Update Metadata

**File: `src/app/layout.tsx`**
```typescript
export const metadata: Metadata = {
  title: 'Zariz Admin Dashboard',
  description: 'Courier order management and dispatch system'
};
```

### 10. Verify Build

```bash
npm run build
npm run dev
```

Visit `http://localhost:3000/dashboard` - should see dashboard layout without auth errors.

## File Structure After Changes

```
web-admin-v2/
├── src/
│   ├── app/
│   │   ├── auth/
│   │   │   └── login/
│   │   │       └── page.tsx (placeholder)
│   │   ├── dashboard/
│   │   │   ├── layout.tsx (cleaned)
│   │   │   ├── page.tsx (overview - keep)
│   │   │   └── overview/ (keep for now)
│   │   ├── layout.tsx (Clerk removed)
│   │   ├── page.tsx (redirect to dashboard)
│   │   └── globals.css
│   ├── components/
│   │   ├── ui/ (all shadcn components - keep)
│   │   ├── layout/ (sidebar, providers - keep)
│   │   └── nav-user.tsx (Clerk removed)
│   ├── lib/
│   │   ├── utils.ts
│   │   └── font.ts
│   ├── hooks/ (keep all)
│   └── middleware.ts (Clerk removed)
├── package.json (Clerk removed)
└── next.config.ts
```

## Dependencies After Cleanup

**Removed:**
- @clerk/nextjs
- @clerk/themes

**Kept (key dependencies):**
- next: 15.3.2
- react: 19.0.0
- @radix-ui/* (all components)
- @tanstack/react-table
- tailwindcss
- next-themes
- sonner (toast notifications)
- lucide-react (icons)

## Testing Checklist

- [ ] `npm install` completes without errors
- [ ] `npm run build` succeeds
- [ ] `npm run dev` starts successfully
- [ ] Navigate to `/dashboard` - layout renders
- [ ] Sidebar visible and functional
- [ ] Theme switcher works
- [ ] No console errors related to Clerk
- [ ] No TypeScript errors

## Notes

- Do NOT implement authentication in this ticket
- Do NOT modify API integration yet
- Focus only on removing Clerk and ensuring the app builds
- Keep all shadcn/ui components intact
- Preserve the dashboard layout structure

## Next Ticket
TICKET-02 will implement Zariz JWT authentication system.

---

## COMPLETION SUMMARY

**Status:** ✅ COMPLETED

**Changes Made:**
1. Cloned `next-shadcn-dashboard-starter` template to `web-admin-v2/`
2. Removed Clerk dependencies from `package.json`:
   - @clerk/nextjs
   - @clerk/themes
3. Replaced Clerk middleware with placeholder in `src/middleware.ts`
4. Updated root layout metadata to "Zariz Admin Dashboard"
5. Removed Clerk auth pages, created placeholder login at `src/app/auth/login/page.tsx`
6. Updated dashboard layout metadata
7. Removed Clerk from components:
   - `src/components/layout/providers.tsx` - removed ClerkProvider wrapper
   - `src/components/layout/app-sidebar.tsx` - replaced useUser with placeholder
   - `src/components/layout/user-nav.tsx` - replaced useUser with placeholder
8. Updated root pages to remove Clerk auth checks:
   - `src/app/page.tsx`
   - `src/app/dashboard/page.tsx`
9. Removed unused template features:
   - `src/features/products/`
   - `src/features/kanban/`
   - `src/features/profile/`
   - `src/features/auth/` (contained Clerk dependencies)
   - `src/app/dashboard/product/`
   - `src/app/dashboard/kanban/`
   - `src/app/dashboard/profile/`

**Verification:**
- ✅ `npm install` completed successfully
- ✅ `npm run build` succeeded with no Clerk errors
- ✅ `npm run dev` started successfully on port 3003
- ✅ Dashboard layout structure preserved (sidebar, header, content area)
- ✅ No TypeScript errors
- ✅ All shadcn/ui components intact

**Files Modified:**
- `/web-admin-v2/package.json`
- `/web-admin-v2/src/middleware.ts`
- `/web-admin-v2/src/app/layout.tsx`
- `/web-admin-v2/src/app/page.tsx`
- `/web-admin-v2/src/app/dashboard/layout.tsx`
- `/web-admin-v2/src/app/dashboard/page.tsx`
- `/web-admin-v2/src/components/layout/providers.tsx`
- `/web-admin-v2/src/components/layout/app-sidebar.tsx`
- `/web-admin-v2/src/components/layout/user-nav.tsx`

**Files Created:**
- `/web-admin-v2/src/app/auth/login/page.tsx`

**Commands to Verify:**
```bash
cd /Users/sasha/IdeaProjects/ios/zariz/web-admin-v2
npm run build  # Should succeed
npm run dev    # Should start on localhost:3000 or next available port
# Navigate to http://localhost:3000/dashboard - layout renders without errors
```
