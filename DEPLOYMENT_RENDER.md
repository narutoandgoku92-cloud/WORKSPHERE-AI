# Render Deployment & PostgreSQL Production Checklist

## 1. Render architecture

- FastAPI backend as a Render Web Service.
- PostgreSQL managed database through Render Databases or external provider.
- Redis cache/lock-store as a separate service (Render Redis or external provider).
- Mobile app connects to the public backend over HTTPS.

## 2. Backend startup

Use this Render start command:

```bash
gunicorn -k uvicorn.workers.UvicornWorker main:app --bind 0.0.0.0:$PORT --workers 2 --threads 4
```

If you need lower latency for load testing, raise workers to `3` and threads to `4`.

## 3. Required Render environment variables

Set these in Render dashboard / secrets:

- `ENVIRONMENT=production`
- `DATABASE_URL=postgresql+psycopg2://<user>:<password>@<host>:<port>/<database>`
- `REDIS_URL=redis://<host>:<port>/<db>`
- `SECRET_KEY=<long-random-secret>`
- `CORS_ORIGINS=https://your-mobile-app-domain.com`
- `ALLOWED_HOSTS=your-backend-service.onrender.com`
- `SENTRY_DSN=` if using Sentry
- `ACCESS_TOKEN_EXPIRE_MINUTES=15`
- `REFRESH_TOKEN_EXPIRE_DAYS=7`

## 4. PostgreSQL setup on Render

1. Create a Render PostgreSQL database service.
2. Copy the generated database URL.
3. Set `DATABASE_URL` in the backend service environment.
4. Do not use SQLite in production.

## 5. Migration workflow

From the backend folder:

```bash
cd backend
pip install -r requirements.txt
alembic revision --autogenerate -m "initial schema"
alembic upgrade head
```

Production workflow:

- Create migrations locally.
- Commit revision files.
- Deploy to Render.
- Use `alembic upgrade head` in the Render service deploy command or as a one-off job.

## 6. Real-user testing checklist

- Build release APK with backend URL via `--dart-define`.
- Upload APK to testers.
- Verify login, attendance, GPS, and face flows.
- Test on mobile data and Wi-Fi.
- Simulate weak signal using carrier throttling or airplane mode toggles.

## 7. Mobile build commands

### Staging build

```bash
flutter build apk --release --dart-define=ENVIRONMENT=staging --dart-define=API_STAGING_BASE_URL=https://your-staging-backend.onrender.com/api/v1
```

### Production build

```bash
flutter build apk --release --dart-define=ENVIRONMENT=production --dart-define=API_PRODUCTION_BASE_URL=https://your-backend-service.onrender.com/api/v1
```

## 8. Security notes

- Use `flutter_secure_storage` for tokens.
- Never hardcode backend URLs in the app.
- Use a strong secret key and rotated refresh tokens.
- Limit `CORS_ORIGINS` and `ALLOWED_HOSTS` to production values.
