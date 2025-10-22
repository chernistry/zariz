# Web Panel - Getting Started

## Prerequisites

- Node.js 20+ (LTS)
- npm 10+ or pnpm 8+
- Git
- Backend API running (see backend setup)

## Project Structure

```
web/
├── src/
│   ├── app/                 # Next.js app directory
│   │   ├── (auth)/         # Auth routes
│   │   ├── (dashboard)/    # Protected dashboard
│   │   └── api/            # API routes
│   ├── components/
│   │   ├── ui/             # Reusable UI components
│   │   ├── orders/         # Order-specific components
│   │   └── layout/         # Layout components
│   ├── lib/
│   │   ├── api.ts          # API client
│   │   ├── auth.ts         # Auth utilities
│   │   └── sse.ts          # Server-Sent Events
│   ├── hooks/              # Custom React hooks
│   ├── types/              # TypeScript types
│   └── styles/             # Global styles
├── public/                 # Static assets
├── tests/
├── package.json
└── next.config.js
```

## Local Development Setup

### 1. Install Dependencies

```bash
cd web

# Using npm
npm install

# Or using pnpm (faster)
pnpm install

# Or using yarn
yarn install
```

### 2. Configure Environment

Create `.env.local`:

```bash
# API Configuration
NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1
NEXT_PUBLIC_WS_URL=http://localhost:8000

# Authentication
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=your-secret-key-change-in-production

# Optional: Analytics
NEXT_PUBLIC_ANALYTICS_ID=

# Optional: Sentry
SENTRY_DSN=
```

### 3. Start Development Server

```bash
# Development mode with hot reload
npm run dev

# On custom port
npm run dev -- -p 3001

# With turbopack (faster)
npm run dev -- --turbo
```

Access at: http://localhost:3000

## CLI Commands

### Development

```bash
# Start dev server
npm run dev

# Build for production
npm run build

# Start production server
npm start

# Type checking
npm run type-check

# Linting
npm run lint

# Format code
npm run format
```

### Testing

```bash
# Run all tests
npm test

# Watch mode
npm run test:watch

# Coverage
npm run test:coverage

# E2E tests (Playwright)
npm run test:e2e

# E2E with UI
npm run test:e2e:ui
```

### Code Quality

```bash
# ESLint
npm run lint
npm run lint:fix

# Prettier
npm run format
npm run format:check

# TypeScript
npm run type-check

# All checks
npm run check-all
```

## Project Setup from Scratch

### Initialize Next.js Project

```bash
npx create-next-app@latest web --typescript --tailwind --app --src-dir

cd web
```

### Install Core Dependencies

```bash
# UI Components
npm install @radix-ui/react-dialog @radix-ui/react-dropdown-menu
npm install @radix-ui/react-select @radix-ui/react-toast

# Forms & Validation
npm install react-hook-form zod @hookform/resolvers

# State Management
npm install zustand

# API & Data Fetching
npm install @tanstack/react-query axios

# Authentication
npm install next-auth

# Date handling
npm install date-fns

# Icons
npm install lucide-react
```

### Install Dev Dependencies

```bash
npm install -D @types/node @types/react @types/react-dom
npm install -D eslint eslint-config-next
npm install -D prettier prettier-plugin-tailwindcss
npm install -D @playwright/test
npm install -D vitest @testing-library/react @testing-library/jest-dom
```

## Development Workflow

### 1. Create New Component

```bash
# Create component file
mkdir -p src/components/orders
touch src/components/orders/OrderCard.tsx
```

```typescript
// src/components/orders/OrderCard.tsx
import { Order } from '@/types/order'

interface OrderCardProps {
  order: Order
  onClaim?: (orderId: string) => void
}

export function OrderCard({ order, onClaim }: OrderCardProps) {
  return (
    <div className="rounded-lg border p-4">
      <h3 className="font-semibold">{order.id}</h3>
      <p className="text-sm text-gray-600">{order.status}</p>
      {onClaim && (
        <button onClick={() => onClaim(order.id)}>
          Claim Order
        </button>
      )}
    </div>
  )
}
```

### 2. Create API Route

```typescript
// src/app/api/orders/route.ts
import { NextRequest, NextResponse } from 'next/server'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const status = searchParams.get('status')
  
  // Fetch from backend
  const response = await fetch(`${process.env.API_URL}/orders?status=${status}`)
  const data = await response.json()
  
  return NextResponse.json(data)
}
```

### 3. Create Page

```typescript
// src/app/(dashboard)/orders/page.tsx
import { OrderList } from '@/components/orders/OrderList'

export default async function OrdersPage() {
  return (
    <div className="container mx-auto py-8">
      <h1 className="text-3xl font-bold mb-6">Orders</h1>
      <OrderList />
    </div>
  )
}
```

### 4. Add Server-Sent Events

```typescript
// src/lib/sse.ts
export function createSSEConnection(url: string) {
  const eventSource = new EventSource(url)
  
  eventSource.onmessage = (event) => {
    const data = JSON.parse(event.data)
    console.log('SSE update:', data)
  }
  
  eventSource.onerror = (error) => {
    console.error('SSE error:', error)
    eventSource.close()
  }
  
  return eventSource
}

// Usage in component
useEffect(() => {
  const sse = createSSEConnection('/api/orders/stream')
  return () => sse.close()
}, [])
```

## Building for Production

### Build

```bash
# Create optimized production build
npm run build

# Analyze bundle size
npm run build -- --analyze
```

### Test Production Build Locally

```bash
# Build and start
npm run build
npm start

# Or with Docker
docker build -t zariz-web .
docker run -p 3000:3000 zariz-web
```

## Deployment

### Deploy to Vercel (Recommended)

```bash
# Install Vercel CLI
npm install -g vercel

# Login
vercel login

# Deploy
vercel

# Production deployment
vercel --prod
```

### Deploy to Netlify

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Login
netlify login

# Deploy
netlify deploy

# Production
netlify deploy --prod
```

### Deploy to VPS (Docker)

```bash
# Build Docker image
docker build -t zariz-web:latest .

# Run container
docker run -d \
  -p 3000:3000 \
  --env-file .env.production \
  --name zariz-web \
  zariz-web:latest

# With docker-compose
docker-compose up -d web
```

**Dockerfile**:
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV production
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
EXPOSE 3000
CMD ["node", "server.js"]
```

### Deploy to Cloud Run (GCP)

```bash
# Build and deploy
gcloud run deploy zariz-web \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars NEXT_PUBLIC_API_URL=$API_URL
```

## Environment Configuration

### Development (.env.local)

```bash
NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=dev-secret-key
```

### Production (.env.production)

```bash
NEXT_PUBLIC_API_URL=https://api.zariz.com/api/v1
NEXTAUTH_URL=https://dashboard.zariz.com
NEXTAUTH_SECRET=production-secret-key-change-this
```

## Testing

### Unit Tests (Vitest)

```typescript
// src/components/orders/OrderCard.test.tsx
import { render, screen } from '@testing-library/react'
import { OrderCard } from './OrderCard'

describe('OrderCard', () => {
  it('renders order information', () => {
    const order = {
      id: '123',
      status: 'new',
      pickup_address: 'Store A'
    }
    
    render(<OrderCard order={order} />)
    expect(screen.getByText('123')).toBeInTheDocument()
  })
})
```

### E2E Tests (Playwright)

```typescript
// tests/e2e/orders.spec.ts
import { test, expect } from '@playwright/test'

test('store can create order', async ({ page }) => {
  await page.goto('http://localhost:3000')
  await page.click('text=Login')
  await page.fill('[name=email]', 'store@example.com')
  await page.fill('[name=password]', 'password')
  await page.click('button[type=submit]')
  
  await page.click('text=Create Order')
  await page.fill('[name=pickup_address]', '123 Main St')
  await page.fill('[name=dropoff_address]', '456 Oak Ave')
  await page.click('button:has-text("Submit")')
  
  await expect(page.locator('text=Order created')).toBeVisible()
})
```

## Performance Optimization

### Image Optimization

```typescript
import Image from 'next/image'

<Image
  src="/logo.png"
  alt="Logo"
  width={200}
  height={50}
  priority
/>
```

### Code Splitting

```typescript
// Dynamic imports
import dynamic from 'next/dynamic'

const OrderMap = dynamic(() => import('@/components/OrderMap'), {
  loading: () => <p>Loading map...</p>,
  ssr: false
})
```

### Caching

```typescript
// src/app/orders/page.tsx
export const revalidate = 60 // Revalidate every 60 seconds

export default async function OrdersPage() {
  const orders = await fetchOrders()
  return <OrderList orders={orders} />
}
```

## Debugging

### Next.js Debug Mode

```bash
NODE_OPTIONS='--inspect' npm run dev
```

Then open `chrome://inspect` in Chrome.

### React DevTools

Install browser extension:
- [Chrome](https://chrome.google.com/webstore/detail/react-developer-tools/fmkadmapgofadopljbjfkapdkoienihi)
- [Firefox](https://addons.mozilla.org/en-US/firefox/addon/react-devtools/)

### Network Debugging

```typescript
// src/lib/api.ts
const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
})

api.interceptors.request.use(request => {
  console.log('Starting Request', request)
  return request
})

api.interceptors.response.use(response => {
  console.log('Response:', response)
  return response
})
```

## Troubleshooting

### Port Already in Use

```bash
# Find process using port 3000
lsof -ti:3000

# Kill process
kill -9 $(lsof -ti:3000)

# Or use different port
npm run dev -- -p 3001
```

### Build Errors

```bash
# Clear Next.js cache
rm -rf .next

# Clear node_modules
rm -rf node_modules package-lock.json
npm install

# Clear all caches
npm run clean
```

### Type Errors

```bash
# Regenerate types
npm run type-check

# Update TypeScript
npm install -D typescript@latest
```

## Security Checklist

- [ ] Environment variables not committed
- [ ] API keys in server-side only
- [ ] CSRF protection enabled
- [ ] XSS prevention (React escapes by default)
- [ ] Content Security Policy configured
- [ ] HTTPS enforced in production
- [ ] Authentication on protected routes
- [ ] Input validation on forms
- [ ] Rate limiting on API routes

## Performance Targets

- First Contentful Paint: < 1.5s
- Time to Interactive: < 3.5s
- Lighthouse Score: > 90
- Bundle size: < 200KB (gzipped)

## Next Steps

1. Configure environment variables
2. Start development server
3. Create authentication flow
4. Build order management UI
5. Implement real-time updates (SSE)
6. Add tests
7. Deploy to staging

## Resources

- [Next.js Documentation](https://nextjs.org/docs)
- [React Documentation](https://react.dev/)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Playwright Docs](https://playwright.dev/)
