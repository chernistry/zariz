# Docker Build Optimization Guide

## Implemented Optimizations

### 1. BuildKit Cache Mounts
- **npm cache**: Кэширует загруженные пакеты между сборками
- **Next.js build cache**: Кэширует результаты компиляции Next.js

### 2. Layer Optimization
- Объединены RUN команды в runner stage (меньше слоёв = быстрее)
- Улучшен порядок COPY для максимального использования кэша

### 3. BuildKit Features
- Включен DOCKER_BUILDKIT=1 для использования современного билдера
- Добавлен --parallel для параллельной сборки сервисов
- Добавлен cache_from для использования предыдущих образов как кэша

### 4. Improved .dockerignore
- Исключены дополнительные файлы (markdown, config files, build artifacts)
- Уменьшен размер build context

## Expected Results

**До оптимизации:**
- Первая сборка: ~70 секунд
- Повторная сборка: ~60-70 секунд

**После оптимизации:**
- Первая сборка: ~60-70 секунд (без изменений)
- Повторная сборка без изменений: ~5-10 секунд (кэш)
- Повторная сборка с изменениями кода: ~20-30 секунд (частичный кэш)

## Additional Recommendations

### 1. Use Docker Layer Caching in CI/CD
```yaml
# GitHub Actions example
- name: Build
  uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

### 2. Pre-build Base Images
Создайте базовый образ с зависимостями:
```bash
# Build base image with dependencies
docker build --target deps -t zariz-web-admin-deps:latest ./web-admin-v2

# Use in Dockerfile
FROM zariz-web-admin-deps:latest AS deps
```

### 3. Use pnpm Instead of npm
pnpm быстрее и эффективнее использует дисковое пространство:
```bash
cd web-admin-v2
npm install -g pnpm
pnpm import  # Convert package-lock.json to pnpm-lock.yaml
```

### 4. Enable Next.js SWC Minifier
В `next.config.ts` (уже включен по умолчанию в Next.js 13+):
```typescript
const config = {
  swcMinify: true,  // Faster than Terser
}
```

### 5. Disable Source Maps in Production
В `next.config.ts`:
```typescript
const config = {
  productionBrowserSourceMaps: false,
}
```

### 6. Use Turbopack (Experimental)
Для dev режима:
```bash
npm run dev -- --turbo
```

### 7. Optimize Docker Desktop Settings
- **Settings → Resources → Advanced**:
  - CPUs: Увеличьте до 4-6 cores
  - Memory: Минимум 4GB, рекомендуется 8GB
  - Disk image size: Минимум 60GB

- **Settings → Docker Engine**:
  ```json
  {
    "builder": {
      "gc": {
        "enabled": true,
        "defaultKeepStorage": "20GB"
      }
    },
    "experimental": true,
    "features": {
      "buildkit": true
    }
  }
  ```

### 8. Clean Build Cache Periodically
```bash
# Remove unused build cache
docker builder prune -af

# Remove all unused data
docker system prune -af --volumes
```

### 9. Use Multi-stage Build Targets for Development
```bash
# Build only deps stage for faster iteration
docker build --target deps -t zariz-web-admin-deps ./web-admin-v2
```

### 10. Consider Docker Compose Watch (Docker Compose v2.22+)
Для dev режима без пересборки:
```yaml
services:
  web-admin:
    develop:
      watch:
        - action: sync
          path: ./web-admin-v2/src
          target: /app/src
        - action: rebuild
          path: ./web-admin-v2/package.json
```

## Monitoring Build Performance

```bash
# Measure build time
time ./run.sh build

# Analyze build cache usage
docker buildx du

# Check layer sizes
docker history zariz-web-admin:latest
```

## Troubleshooting

### Cache Not Working
```bash
# Clear Docker build cache
docker builder prune -af

# Rebuild without cache
DOCKER_BUILDKIT=1 docker compose build --no-cache
```

### Out of Disk Space
```bash
# Check disk usage
docker system df

# Clean up
docker system prune -af --volumes
```

### Slow Network
```bash
# Use npm/pnpm mirror (for Russia/China)
npm config set registry https://registry.npmmirror.com
```
