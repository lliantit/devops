# Delivery API Microservice

Бекенд-сервіс доставки на базі Node.js (Express) та бази даних MongoDB. Проєкт контейнеризовано за допомогою Docker, інтегровано з CI/CD пайплайном GitHub Actions та розгорнуто в кластері Kubernetes[cite: 1].

---

## Стек технологій

- **Backend:** Node.js 18, Express
- **Database:** MongoDB 6.0 (Mongoose ODM)
- **Testing & Linting:** Jest, Supertest, ESLint
- **Containerization & CI/CD:** Docker, Docker Compose, GitHub Actions, GitHub Container Registry (GHCR)
- **Orchestration:** Kubernetes (Minikube, Kubectl)[cite: 1]

---

## Локальний запуск через Docker Compose (Лабораторна робота №1)

Запуск сервісу API та бази даних MongoDB у ізольованих контейнерах:

```bash
docker compose up -d --build
```

Перевірка працездатності сервісу:
- Endpoint стану: `http://localhost:3001/health` (відповідь: `{"status":"OK"}`)

---

## CI/CD Пайплайн (Лабораторна робота №2)

У репозиторії налаштовано автоматизований пайплайн GitHub Actions (`.github/workflows/ci.yml`), який виконує:
- **Lint Code:** статичний аналіз коду за допомогою ESLint (`npm run lint`).
- **Build & Test:** запуск автоматизованих тестів Jest (`npm test`) із кешуванням залежностей npm.
- **Docker Build & Push:** автоматичну збірку та публікацію Docker-образу в реєстр `ghcr.io` (з тегами `latest` та коротким `SHA` коміту) після успішного проходження перевірок у гілці `main`.

---

## Розгортання в кластері Kubernetes (Лабораторна робота №3)[cite: 1]

Усі Kubernetes-маніфести розташовані в каталозі `k8s/` (по одному файлу на об'єкт) та ізольовані у власному просторі імен `delivery-app`[cite: 1].

### 1. Запуск локального кластера та підготовка середовища[cite: 1]

```bash
# Запуск локального кластера Minikube з драйвером Docker
minikube start --driver=docker

# Увімкнення обов'язкових доповнень
minikube addons enable metrics-server
minikube addons enable ingress

# Перевірка стану вузла та системних подів
kubectl get nodes
kubectl get pods -n kube-system
```

### 2. Підготовка та завантаження версій образу в Minikube[cite: 1]

Для демонстрації життєвого циклу, оновлення (Rolling Update) та відкату без використання тегу `latest` збираються дві версії образу (`1.0.0` та `1.1.0`)[cite: 1]:

```bash
docker build -t delivery-api:1.0.0 .
minikube image load delivery-api:1.0.0

docker build -t delivery-api:1.1.0 .
minikube image load delivery-api:1.1.0
```

### 3. Розгортання застосунку однією командою[cite: 1, 2]

Застосування всіх маніфестів із каталогу `k8s/`[cite: 1, 2]:

```bash
kubectl apply -f k8s/
```

Перевірка статусу створених об'єктів (Pod, Deployment, ReplicaSet, Service, PVC, Ingress)[cite: 1]:

```bash
kubectl get all,pvc,ingress -n delivery-app
```

### 4. Доступ до застосунку та перевірка роботи[cite: 1]

Прокидання порту сервісу `api-service` на локальну машину:

```bash
kubectl port-forward -n delivery-app service/api-service 8780:3000
```

Перевірка у браузері:
- Адреса: `http://localhost:8780/health`
- Очікувана відповідь: `{"status":"OK"}`

---

## Перелік параметрів у ConfigMap і Secret[cite: 2]

Конфігурація застосунку відокремлена від образу контейнера та передається в поди `api-deployment` через змінні оточення[cite: 1]:

### ConfigMap (`k8s/01-configmap.yaml` — об'єкт `api-config`)[cite: 1, 2]
- `PORT` — мережевий порт, на якому запускається Express-сервер всередині контейнера (значення: `"3000"`).
- `NODE_ENV` — режим середовища виконання застосунку Node.js (значення: `"production"`).

### Secret (`k8s/02-secret.yaml` — об'єкт `api-secret`)[cite: 1, 2]
- `MONGO_URI` — чутливий параметр із рядком підключення до бази даних MongoDB через внутрішній сервіс кластера (значення: `"mongodb://mongo-service:27017/delivery"`).

---

## Опис маніфестів у каталозі `k8s/`[cite: 1]

- `00-namespace.yaml` — створення окремого простору імен `delivery-app`[cite: 1].
- `01-configmap.yaml` — конфігураційні змінні оточення (`PORT`, `NODE_ENV`)[cite: 1].
- `02-secret.yaml` — секретні дані (`MONGO_URI`)[cite: 1].
- `03-mongo-pvc.yaml` — запит на постійне сховище `PersistentVolumeClaim` обсягом `1Gi` (`ReadWriteOnce`) для збереження даних MongoDB[cite: 1].
- `04-mongo-deployment.yaml` — розгортання бази даних `mongo:6.0` із примонтованим томом `mongo-pvc` та обмеженнями ресурсів[cite: 1].
- `05-mongo-service.yaml` — внутрішній сервіс `ClusterIP` для доступу до бази даних на порту `27017`[cite: 1].
- `06-api-deployment.yaml` — розгортання застосунку `delivery-api` (2 репліки, налаштовані `requests` і `limits` для CPU та пам'яті, перевірки стану `livenessProbe` та `readinessProbe` за шляхом `/health`)[cite: 1].
- `07-api-service.yaml` — сервіс `ClusterIP` для балансування навантаження між подами API на порту `3000`[cite: 1].
- `08-ingress.yaml` — конфігурація вхідного контролера Ingress для маршрутизації HTTP-запитів із хоста `delivery.local` на `api-service`[cite: 1].

---

## Команди керування життєвим циклом та діагностики[cite: 2]

```bash
# Перевірка змінних ConfigMap і Secret всередині контейнера
kubectl exec -n delivery-app deployment/api-deployment -- env

# Масштабування кількості реплік
kubectl scale deployment api-deployment --replicas=4 -n delivery-app

# Оновлення версії образу (Rolling Update)
kubectl set image deployment/api-deployment delivery-api=delivery-api:1.1.0 -n delivery-app
kubectl rollout status deployment/api-deployment -n delivery-app

# Історія ревізій та відкат до попередньої версії
kubectl rollout history deployment/api-deployment -n delivery-app
kubectl rollout undo deployment/api-deployment -n delivery-app

# Перегляд логів та подій для діагностики
kubectl logs -n delivery-app deployment/api-deployment
kubectl describe pod <pod-name> -n delivery-app
```

---

## Розгортання через Helm-чарт (Лабораторна робота №4)

Застосунок спаковано у власний Helm-чарт `helm/delivery-chart`, що параметризує маніфести Kubernetes для різних середовищ розгортання (`dev` та `prod`).

### Різниця між `version` та `appVersion` у `Chart.yaml`
- `version` (`0.1.0`) — семантична версія самого Helm-чарта (його шаблонів, конфігурацій та структури). Змінюється при редагуванні маніфестів чи дефолтних значень.
- `appVersion` (`1.0.0`) — версія коду та образу самого бекенд-застосунку Delivery API, що пакується та розгортається цим чартом.

### Пріоритет передачі значень у Helm
1. **Прапорець `--set`** у командному рядку — має найвищий пріоритет та перекриває будь-які конфігураційні файли.
2. **Файли значень (`-f values-<env>.yaml`)** — перекривають дефолтні значення чарта. При вказанні кількох файлів пріоритет має останній.
3. **Файл `values.yaml`** у корені чарта — містить базові значення за замовчуванням (найнижчий пріоритет).

### Таблиця параметрів конфігурації (`values.yaml`)

| Параметр | Опис | Значення за замовчуванням |
|---|---|---|
| `replicaCount` | Кількість реплік API-сервісу | `1` |
| `image.repository` | Назва Docker-образу бекенду | `delivery-api` |
| `image.tag` | Тег версії образу | `"1.0.0"` |
| `image.pullPolicy` | Політика завантаження образу | `IfNotPresent` |
| `service.type` | Тип Kubernetes Service для API | `ClusterIP` |
| `service.port` | Порт доступу до сервісу | `3000` |
| `resources.requests` | Гарантовані ресурси CPU/пам'яті | `50m` / `64Mi` |
| `resources.limits` | Максимальні ліміти CPU/пам'яті | `150m` / `128Mi` |
| `config.port` | Внутрішній порт сервера Node.js | `"3000"` |
| `config.nodeEnv` | Режим середовища (`development`/`production`) | `"development"` |
| `secret.mongoDatabase` | Назва бази даних у MongoDB | `"delivery"` |
| `mongodb.image` | Базовий образ MongoDB | `"mongo:6.0"` |
| `mongodb.port` | Порт підключення до MongoDB | `27017` |
| `mongodb.pvc.enabled` | Прапорець створення постійного тому | `true` |
| `mongodb.pvc.storage` | Обсяг виділеного сховища для БД | `1Gi` |
| `ingress.enabled` | Увімкнення маршрутизації через Ingress | `false` |
| `ingress.host` | Доменне ім'я для зовнішнього доступу | `delivery.local` |

### Команди встановлення для різних середовищ

**Середовище розробки (Development):**
```bash
helm install delivery-release helm/delivery-chart -f helm/delivery-chart/values-dev.yaml -n delivery-app
```

**Продуктове середовище (Production):**
```bash
helm install delivery-release helm/delivery-chart -f helm/delivery-chart/values-prod.yaml -n delivery-app
```

### Керування життєвим циклом та тестування
```bash
# Запуск інтеграційного тесту релізу (завдання 9.b)
helm test delivery-release -n delivery-app

# Оновлення тегу образу на льоту
helm upgrade delivery-release helm/delivery-chart --reuse-values --set image.tag="1.1.0" -n delivery-app

# Перегляд історії ревізій
helm history delivery-release -n delivery-app

# Відкат до попередньої робочої ревізії
helm rollback delivery-release 1 -n delivery-app

# Повне видалення релізу
helm uninstall delivery-release -n delivery-app
```