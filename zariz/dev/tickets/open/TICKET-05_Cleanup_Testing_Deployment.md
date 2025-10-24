# TICKET-05: Final Cleanup, Testing, and Deployment Preparation

**READ FIRST:** `/Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md`

## Objective
Complete the migration by cleaning up unused code, comprehensive testing, updating documentation, and preparing for production deployment.

## Context
This is the final ticket to ensure the new web-admin-v2 is production-ready and can replace the current web-admin.

## Acceptance Criteria
- [ ] All unused template code removed
- [ ] Environment variables documented
- [ ] Docker configuration updated
- [ ] README updated with new setup instructions
- [ ] All features tested end-to-end
- [ ] Performance optimized
- [ ] Accessibility checked
- [ ] Production build succeeds
- [ ] Deployment guide created

## Implementation Steps

### 1. Remove Unused Template Code

**Delete unused features:**
```bash
cd web-admin-v2

# Remove unused app routes
rm -rf src/app/dashboard/overview

# Remove unused components
rm -rf src/features/overview
rm -rf src/components/kbar  # if not using command palette

# Remove unused constants
# Edit src/constants/data.ts - remove mock data if not used
```

**Clean up package.json:**
Remove unused dependencies:
```json
// Remove if not used:
"@dnd-kit/*",  // drag and drop
"kbar",  // command palette
"react-dropzone",  // file upload
"recharts",  // charts (if not using dashboard)
"@sentry/nextjs",  // if not using Sentry
"motion",  // animations
"vaul",  // drawer
"cmdk",  // command menu
"input-otp",  // OTP input
"react-day-picker",  // date picker (if not using)
"react-resizable-panels",  // resizable panels
"zustand"  // state management (if not using)
```

Keep essential dependencies:
```json
{
  "dependencies": {
    "next": "15.3.2",
    "react": "19.0.0",
    "react-dom": "19.0.0",
    "@radix-ui/*": "...",  // all UI components
    "@tanstack/react-table": "...",
    "tailwindcss": "...",
    "next-themes": "...",
    "sonner": "...",  // toasts
    "lucide-react": "...",  // icons
    "class-variance-authority": "...",
    "clsx": "...",
    "tailwind-merge": "...",
    "tailwindcss-animate": "...",
    "nextjs-toploader": "..."
  }
}
```

### 2. Update Environment Configuration

**File: `.env.example`**
```bash
# API Configuration
NEXT_PUBLIC_API_BASE=http://localhost:8000/v1

# Authentication
NEXT_PUBLIC_AUTH_REFRESH=1

# Optional: Sentry (if using)
# NEXT_PUBLIC_SENTRY_DSN=
# SENTRY_AUTH_TOKEN=
```

**File: `.env.local`** (for development)
```bash
NEXT_PUBLIC_API_BASE=http://localhost:8000/v1
NEXT_PUBLIC_AUTH_REFRESH=1
```

**File: `.env.production`** (for production)
```bash
NEXT_PUBLIC_API_BASE=https://api.zariz.app/v1
NEXT_PUBLIC_AUTH_REFRESH=1
```

### 3. Update Docker Configuration

**File: `Dockerfile`**
```dockerfile
FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Set environment variables for build
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Set the correct permission for prerender cache
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Automatically leverage output traces to reduce image size
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
```

**File: `next.config.ts`**
```typescript
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'standalone',
  reactStrictMode: true,
  poweredByHeader: false,
  compress: true,
  
  // Disable telemetry
  telemetry: false,
  
  // Image optimization
  images: {
    formats: ['image/avif', 'image/webp'],
    remotePatterns: []
  },
  
  // Security headers
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          {
            key: 'X-DNS-Prefetch-Control',
            value: 'on'
          },
          {
            key: 'Strict-Transport-Security',
            value: 'max-age=63072000; includeSubDomains; preload'
          },
          {
            key: 'X-Frame-Options',
            value: 'SAMEORIGIN'
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff'
          },
          {
            key: 'X-XSS-Protection',
            value: '1; mode=block'
          },
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin'
          }
        ]
      }
    ];
  }
};

export default nextConfig;
```

**File: `.dockerignore`**
```
.git
.gitignore
.next
.env*.local
node_modules
npm-debug.log
README.md
.vscode
.idea
*.md
```

### 4. Update README

**File: `README.md`**
```markdown
# Zariz Web Admin

Modern admin dashboard for Zariz courier order management system, built with Next.js 15 and shadcn/ui.

## Features

- 🔐 JWT-based authentication with auto-refresh
- 📦 Order management with real-time updates (SSE)
- 🏪 Store management
- 🚚 Courier management
- 📊 Data tables with filtering and sorting
- 📥 CSV export
- 🎨 Modern UI with shadcn/ui components
- 🌓 Dark mode support
- 📱 Responsive design

## Tech Stack

- **Framework:** Next.js 15 (App Router)
- **UI:** shadcn/ui + Radix UI + Tailwind CSS
- **State:** React hooks + Context
- **Auth:** JWT (access + refresh tokens)
- **Real-time:** Server-Sent Events (SSE)
- **Icons:** Lucide React
- **Notifications:** Sonner

## Prerequisites

- Node.js 20+
- npm or pnpm
- Zariz backend API running

## Getting Started

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment

Copy `.env.example` to `.env.local`:

```bash
cp .env.example .env.local
```

Edit `.env.local`:

```bash
NEXT_PUBLIC_API_BASE=http://localhost:8000/v1
NEXT_PUBLIC_AUTH_REFRESH=1
```

### 3. Run Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) and login with admin credentials.

### 4. Build for Production

```bash
npm run build
npm start
```

## Docker Deployment

### Build Image

```bash
docker build -t zariz-web-admin .
```

### Run Container

```bash
docker run -p 3000:3000 \
  -e NEXT_PUBLIC_API_BASE=https://api.zariz.app/v1 \
  -e NEXT_PUBLIC_AUTH_REFRESH=1 \
  zariz-web-admin
```

### Docker Compose

Add to your `docker-compose.yml`:

```yaml
web-admin:
  build: ./web-admin-v2
  ports:
    - "3002:3000"
  environment:
    - NEXT_PUBLIC_API_BASE=http://backend:8000/v1
    - NEXT_PUBLIC_AUTH_REFRESH=1
  depends_on:
    - backend
```

## Project Structure

```
src/
├── app/
│   ├── auth/
│   │   └── login/          # Login page
│   ├── dashboard/
│   │   ├── orders/         # Orders management
│   │   ├── stores/         # Stores management
│   │   └── couriers/       # Couriers management
│   ├── api/
│   │   └── auth/           # Auth API routes
│   ├── layout.tsx          # Root layout
│   └── page.tsx            # Home (redirects to dashboard)
├── components/
│   ├── ui/                 # shadcn/ui components
│   ├── layout/             # Layout components (sidebar, header)
│   └── modals/             # Dialog components
├── lib/
│   ├── api.ts              # API client
│   ├── auth-client.ts      # Auth client
│   └── utils.ts            # Utilities
├── hooks/
│   ├── use-auth.ts         # Auth hook
│   └── use-sse.ts          # SSE hook
└── middleware.ts           # Auth middleware
```

## Authentication

The app uses JWT-based authentication:

1. **Access Token:** Short-lived, stored in memory
2. **Refresh Token:** Long-lived, stored in HTTP-only cookie
3. **Auto-refresh:** Scheduled 120s before expiry
4. **Admin-only:** Non-admin users are rejected

### Login Flow

1. User enters credentials
2. API returns access + refresh tokens
3. Access token stored in memory
4. Refresh token stored in HTTP-only cookie
5. Auto-refresh scheduled

### Protected Routes

All `/dashboard/*` routes require authentication. Middleware checks for refresh token and redirects to `/auth/login` if missing.

## Real-time Updates

Orders page uses Server-Sent Events (SSE) for real-time updates:

```typescript
useSSE(`${API_BASE}/events/sse`, (msg) => {
  if (msg.type.startsWith('order.')) {
    refresh();
  }
});
```

## Development

### Code Style

```bash
npm run lint
npm run format
```

### Type Checking

```bash
npx tsc --noEmit
```

## Troubleshooting

### Login fails
- Check backend API is running
- Verify `NEXT_PUBLIC_API_BASE` is correct
- Check browser console for errors

### Real-time updates not working
- Verify SSE endpoint is accessible
- Check browser network tab for SSE connection
- Ensure backend supports SSE

### Build fails
- Clear `.next` directory: `rm -rf .next`
- Delete `node_modules` and reinstall: `rm -rf node_modules && npm install`
- Check for TypeScript errors: `npx tsc --noEmit`

## License

Proprietary - Zariz
```

### 5. Performance Optimization

**Add to `next.config.ts`:**
```typescript
experimental: {
  optimizePackageImports: ['lucide-react', '@radix-ui/react-icons']
}
```

**Optimize images:**
- Use Next.js Image component for all images
- Add proper width/height attributes
- Use WebP format

**Code splitting:**
- Use dynamic imports for heavy components
- Lazy load modals and dialogs

**Example:**
```typescript
import dynamic from 'next/dynamic';

const AssignCourierDialog = dynamic(
  () => import('@/components/modals/assign-courier-dialog'),
  { ssr: false }
);
```

### 6. Accessibility Audit

**Run Lighthouse:**
```bash
npm run build
npm start
# Open Chrome DevTools > Lighthouse > Run audit
```

**Check:**
- [ ] All interactive elements keyboard accessible
- [ ] Proper ARIA labels on buttons/inputs
- [ ] Color contrast meets WCAG AA
- [ ] Focus indicators visible
- [ ] Screen reader friendly

**Fix common issues:**
```typescript
// Add aria-label to icon buttons
<Button aria-label="Delete order">
  <Trash className="h-4 w-4" />
</Button>

// Add proper labels to inputs
<Label htmlFor="email">Email</Label>
<Input id="email" type="email" />
```

### 7. Integration Testing

**Create test checklist:**

**File: `TESTING.md`**
```markdown
# Testing Checklist

## Authentication
- [ ] Login with valid credentials
- [ ] Login with invalid credentials shows error
- [ ] Logout works
- [ ] Auto-refresh works (wait 2+ minutes)
- [ ] Non-admin users rejected
- [ ] Session persists on page refresh
- [ ] Accessing protected route without auth redirects to login

## Orders
- [ ] List displays all orders
- [ ] Filters work (status, store, courier, dates)
- [ ] Real-time updates work (create order in backend)
- [ ] CSV export downloads file
- [ ] View order navigates to detail
- [ ] Assign courier works
- [ ] Cancel order works
- [ ] Delete order works
- [ ] Error handling works (disconnect backend)

## Stores
- [ ] List displays all stores
- [ ] Search filters stores
- [ ] Create store works
- [ ] Edit store works
- [ ] Status changes work
- [ ] Form validation works

## Couriers
- [ ] List displays all couriers
- [ ] Search filters couriers
- [ ] Create courier works
- [ ] Edit courier works
- [ ] Status changes work
- [ ] Capacity boxes field works

## UI/UX
- [ ] Theme switcher works (light/dark)
- [ ] Responsive on mobile
- [ ] Sidebar collapsible
- [ ] Loading states display
- [ ] Error toasts show
- [ ] Success toasts show
- [ ] Navigation works

## Performance
- [ ] Initial load < 3s
- [ ] Page transitions smooth
- [ ] No console errors
- [ ] No memory leaks (check DevTools)
```

### 8. Update run.sh Script

**File: `/Users/sasha/IdeaProjects/ios/zariz/run.sh`** (add)
```bash
# Web Admin v2 commands
web-admin:dev() {
  cd web-admin-v2
  npm run dev
}

web-admin:build() {
  cd web-admin-v2
  npm run build
}

web-admin:start() {
  cd web-admin-v2
  npm start
}
```

### 9. Update Docker Compose

**File: `docker-compose.yml`** (update web-admin service)
```yaml
web-admin:
  build:
    context: ./web-admin-v2
    dockerfile: Dockerfile
  ports:
    - "3002:3000"
  environment:
    - NEXT_PUBLIC_API_BASE=http://backend:8000/v1
    - NEXT_PUBLIC_AUTH_REFRESH=1
  depends_on:
    - backend
  restart: unless-stopped
```

### 10. Create Migration Guide

**File: `MIGRATION.md`**
```markdown
# Migration from web-admin to web-admin-v2

## Changes

### UI Framework
- **Before:** Material UI
- **After:** shadcn/ui + Radix UI + Tailwind CSS

### Routing
- **Before:** Pages Router (Next.js 12)
- **After:** App Router (Next.js 15)

### Authentication
- **Before:** Same (JWT + refresh)
- **After:** Same implementation, new structure

### Features
- All existing features preserved
- Improved UI/UX
- Better performance
- Modern component library

## Deployment Steps

1. **Test new version:**
   ```bash
   cd web-admin-v2
   npm install
   npm run build
   npm start
   ```

2. **Verify all features work**

3. **Update Docker Compose:**
   - Point web-admin service to web-admin-v2
   - Rebuild: `docker-compose build web-admin`

4. **Deploy:**
   ```bash
   docker-compose up -d web-admin
   ```

5. **Rollback if needed:**
   - Point back to web-admin
   - Rebuild and restart

## Breaking Changes

None - API contract unchanged.

## Known Issues

None at this time.
```

## Testing Checklist

- [ ] All features tested per TESTING.md
- [ ] Performance audit passed (Lighthouse score > 90)
- [ ] Accessibility audit passed (no critical issues)
- [ ] Docker build succeeds
- [ ] Docker container runs successfully
- [ ] Production build optimized (check bundle size)
- [ ] No console errors in production
- [ ] All environment variables documented

## Deployment Checklist

- [ ] README.md updated
- [ ] MIGRATION.md created
- [ ] Docker configuration tested
- [ ] Environment variables set
- [ ] run.sh updated
- [ ] docker-compose.yml updated
- [ ] All dependencies up to date
- [ ] Security headers configured
- [ ] HTTPS enforced in production

## Notes

- Keep old web-admin directory until migration verified
- Monitor production for issues
- Collect user feedback
- Plan for gradual rollout if needed

## Success Criteria

- [ ] All acceptance criteria met
- [ ] Production deployment successful
- [ ] No critical bugs reported
- [ ] Performance meets or exceeds old version
- [ ] User feedback positive
