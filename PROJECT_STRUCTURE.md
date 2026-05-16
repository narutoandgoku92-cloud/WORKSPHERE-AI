# PROJECT_STRUCTURE.md - Complete OptiWork AI Project Organization

## Complete Directory Structure

```
optiwork-ai/
│
├── backend/                          # FastAPI Backend (Python)
│   ├── main.py                      # Application entry point
│   ├── requirements.txt             # Python dependencies
│   ├── .env.example                 # Environment variables template
│   │
│   ├── core/                        # Core application modules
│   │   ├── __init__.py
│   │   ├── config.py                # Settings and configuration
│   │   ├── database.py              # Database setup and session
│   │   ├── security.py              # JWT, auth, encryption
│   │   └── constants.py             # Application constants
│   │
│   ├── models/                      # SQLAlchemy ORM models
│   │   ├── __init__.py
│   │   ├── user.py                  # User, Role, Session models
│   │   ├── organization.py          # Organization, Department models
│   │   ├── attendance.py            # Attendance tracking models
│   │   ├── face_enrollment.py       # Face enrollment models
│   │   ├── gps.py                   # GPS location models
│   │   ├── payroll.py               # Payroll models
│   │   ├── analytics.py             # Metrics and analytics models
│   │   ├── notification.py          # Notification models
│   │   └── audit.py                 # Audit log models
│   │
│   ├── schemas/                     # Pydantic request/response schemas
│   │   ├── __init__.py
│   │   ├── auth.py                  # Auth request/response
│   │   ├── user.py                  # User schemas
│   │   ├── attendance.py            # Attendance schemas
│   │   ├── face.py                  # Face recognition schemas
│   │   ├── payroll.py               # Payroll schemas
│   │   └── common.py                # Common schemas
│   │
│   ├── services/                    # Business logic services
│   │   ├── __init__.py
│   │   ├── face_recognition.py      # Facial recognition AI
│   │   ├── gps_service.py           # GPS & geofencing
│   │   ├── analytics_service.py     # Analytics engine
│   │   ├── payroll_service.py       # Payroll computation
│   │   ├── attendance_service.py    # Attendance logic
│   │   ├── email_service.py         # Email notifications
│   │   ├── storage_service.py       # AWS S3 integration
│   │   ├── cache.py                 # Redis caching
│   │   └── notification_service.py  # Push notifications
│   │
│   ├── repositories/                # Data access layer
│   │   ├── __init__.py
│   │   ├── base_repository.py       # Base repository
│   │   ├── user_repository.py
│   │   ├── attendance_repository.py
│   │   ├── face_repository.py
│   │   ├── analytics_repository.py
│   │   └── payroll_repository.py
│   │
│   ├── api/                         # API routes
│   │   ├── v1/
│   │   │   ├── __init__.py
│   │   │   ├── routes/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── auth.py          # Auth endpoints
│   │   │   │   ├── users.py         # User endpoints
│   │   │   │   ├── attendance.py    # Attendance endpoints
│   │   │   │   ├── face_recognition.py
│   │   │   │   ├── gps.py           # GPS endpoints
│   │   │   │   ├── analytics.py     # Analytics endpoints
│   │   │   │   ├── payroll.py       # Payroll endpoints
│   │   │   │   └── admin.py         # Admin endpoints
│   │   │   └── dependencies.py      # FastAPI dependencies
│   │
│   ├── middleware/                  # Custom middleware
│   │   ├── __init__.py
│   │   ├── auth.py                  # JWT middleware
│   │   ├── error_handler.py         # Error handling
│   │   ├── logging.py               # Request logging
│   │   └── rate_limit.py            # Rate limiting
│   │
│   ├── tasks/                       # Background tasks (Celery)
│   │   ├── __init__.py
│   │   ├── celery.py                # Celery configuration
│   │   ├── attendance_tasks.py      # Attendance tasks
│   │   ├── payroll_tasks.py         # Payroll tasks
│   │   ├── analytics_tasks.py       # Analytics tasks
│   │   ├── notification_tasks.py    # Notification tasks
│   │   └── email_tasks.py           # Email tasks
│   │
│   ├── utils/                       # Utility functions
│   │   ├── __init__.py
│   │   ├── validators.py            # Input validation
│   │   ├── formatters.py            # Data formatters
│   │   ├── helpers.py               # Helper functions
│   │   ├── exceptions.py            # Custom exceptions
│   │   └── decorators.py            # Custom decorators
│   │
│   ├── migrations/                  # Alembic database migrations
│   │   ├── env.py
│   │   ├── script.py.mako
│   │   └── versions/
│   │
│   ├── tests/                       # Unit and integration tests
│   │   ├── __init__.py
│   │   ├── conftest.py              # Pytest configuration
│   │   ├── test_auth.py
│   │   ├── test_attendance.py
│   │   ├── test_face_recognition.py
│   │   └── test_payroll.py
│   │
│   ├── Dockerfile                   # Docker container
│   ├── docker-compose.yml           # Local development setup
│   └── .dockerignore
│
├── mobile/                          # Flutter Mobile App
│   ├── pubspec.yaml                # Flutter dependencies
│   ├── android/                    # Android native code
│   ├── ios/                        # iOS native code
│   ├── lib/
│   │   ├── main.dart               # Entry point
│   │   ├── config/
│   │   │   ├── app_config.dart
│   │   │   ├── theme.dart          # Material theme
│   │   │   └── constants.dart
│   │   ├── models/
│   │   │   ├── user.dart
│   │   │   ├── attendance.dart
│   │   │   ├── payroll.dart
│   │   │   └── analytics.dart
│   │   ├── providers/              # Riverpod state management
│   │   │   ├── auth_provider.dart
│   │   │   ├── attendance_provider.dart
│   │   │   └── analytics_provider.dart
│   │   ├── services/
│   │   │   ├── api_service.dart
│   │   │   ├── auth_service.dart
│   │   │   ├── face_recognition_service.dart
│   │   │   ├── gps_service.dart
│   │   │   └── notification_service.dart
│   │   ├── screens/
│   │   │   ├── auth/
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── face_enrollment_screen.dart
│   │   │   │   └── biometric_login_screen.dart
│   │   │   ├── home/
│   │   │   │   ├── home_screen.dart
│   │   │   │   └── dashboard_screen.dart
│   │   │   ├── attendance/
│   │   │   │   ├── clock_in_screen.dart
│   │   │   │   ├── attendance_history_screen.dart
│   │   │   │   └── verification_screen.dart
│   │   │   ├── analytics/
│   │   │   │   ├── productivity_screen.dart
│   │   │   │   ├── insights_screen.dart
│   │   │   │   └── charts_screen.dart
│   │   │   ├── payroll/
│   │   │   │   ├── payslip_screen.dart
│   │   │   │   └── payroll_history_screen.dart
│   │   │   └── settings/
│   │   │       ├── profile_screen.dart
│   │   │       ├── device_management_screen.dart
│   │   │       └── settings_screen.dart
│   │   ├── widgets/
│   │   │   ├── common/
│   │   │   │   ├── custom_app_bar.dart
│   │   │   │   ├── custom_button.dart
│   │   │   │   ├── custom_input.dart
│   │   │   │   └── custom_card.dart
│   │   │   ├── attendance/
│   │   │   │   ├── clock_in_card.dart
│   │   │   │   └── verification_widget.dart
│   │   │   └── analytics/
│   │   │       ├── productivity_chart.dart
│   │   │       └── insight_card.dart
│   │   ├── utils/
│   │   │   ├── validators.dart
│   │   │   ├── formatters.dart
│   │   │   └── extensions.dart
│   │   └── l10n/
│   │       └── (localization files)
│   └── test/
│       ├── unit/
│       ├── widget/
│       └── integration/
│
├── web/                            # Next.js Web Dashboard
│   ├── package.json               # Node dependencies
│   ├── tsconfig.json              # TypeScript config
│   ├── next.config.js             # Next.js config
│   ├── tailwind.config.js         # Tailwind CSS config
│   │
│   ├── app/                       # Next.js app directory
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   ├── auth/
│   │   │   ├── login/page.tsx
│   │   │   ├── register/page.tsx
│   │   │   └── reset-password/page.tsx
│   │   ├── dashboard/
│   │   │   ├── page.tsx           # Main dashboard
│   │   │   ├── analytics/page.tsx
│   │   │   ├── workforce/page.tsx
│   │   │   ├── attendance/page.tsx
│   │   │   ├── payroll/page.tsx
│   │   │   ├── reports/page.tsx
│   │   │   └── settings/page.tsx
│   │   └── api/
│   │       ├── auth/route.ts
│   │       ├── webhook/route.ts
│   │       └── proxy/[...path]/route.ts
│   │
│   ├── components/
│   │   ├── common/
│   │   │   ├── Navbar.tsx
│   │   │   ├── Sidebar.tsx
│   │   │   ├── Header.tsx
│   │   │   └── ThemeToggle.tsx
│   │   ├── dashboard/
│   │   │   ├── DashboardGrid.tsx
│   │   │   ├── MetricCard.tsx
│   │   │   ├── RealtimeAlert.tsx
│   │   │   └── AIInsightPanel.tsx
│   │   ├── analytics/
│   │   │   ├── PerformanceChart.tsx
│   │   │   ├── AttendanceHeatmap.tsx
│   │   │   ├── ProductivityMetrics.tsx
│   │   │   ├── TrendAnalysis.tsx
│   │   │   └── PredictionPanel.tsx
│   │   ├── workforce/
│   │   │   ├── EmployeeTable.tsx
│   │   │   ├── LiveMap.tsx
│   │   │   ├── GeofenceManager.tsx
│   │   │   └── EmployeeDetails.tsx
│   │   ├── payroll/
│   │   │   ├── PayrollForm.tsx
│   │   │   ├── PayslipGenerator.tsx
│   │   │   ├── PayrollHistory.tsx
│   │   │   └── TaxCalculator.tsx
│   │   └── forms/
│   │       ├── UserForm.tsx
│   │       ├── DepartmentForm.tsx
│   │       └── SettingsForm.tsx
│   │
│   ├── lib/
│   │   ├── api.ts                 # API client
│   │   ├── auth.ts                # Auth utilities
│   │   ├── hooks/                 # React custom hooks
│   │   │   ├── useAuth.ts
│   │   │   ├── useDashboard.ts
│   │   │   └── useAnalytics.ts
│   │   ├── store/                 # Zustand state management
│   │   │   ├── authStore.ts
│   │   │   ├── uiStore.ts
│   │   │   └── dataStore.ts
│   │   ├── utils/
│   │   │   ├── validators.ts
│   │   │   ├── formatters.ts
│   │   │   └── helpers.ts
│   │   └── types/                 # TypeScript types
│   │       ├── api.ts
│   │       ├── models.ts
│   │       └── index.ts
│   │
│   ├── styles/
│   │   ├── globals.css
│   │   ├── theme.ts
│   │   └── animations.css
│   │
│   ├── public/
│   │   ├── icons/
│   │   ├── images/
│   │   └── animations/
│   │
│   ├── config/
│   │   └── site.config.ts
│   │
│   ├── .env.local.example
│   ├── Dockerfile
│   └── .dockerignore
│
├── ai_services/                    # Python AI/ML microservices
│   ├── requirements.txt
│   ├── main.py
│   ├── services/
│   │   ├── face_recognition.py    # Face recognition service
│   │   ├── analytics_engine.py    # Analytics & predictions
│   │   ├── anomaly_detection.py   # Anomaly detection
│   │   └── forecasting.py         # Time series forecasting
│   ├── models/                    # Trained ML models
│   ├── Dockerfile
│   └── docker-compose.yml
│
├── infrastructure/                 # DevOps & Infrastructure
│   ├── docker-compose.yml         # Local development
│   ├── docker-compose.prod.yml    # Production setup
│   │
│   ├── docker/
│   │   ├── Dockerfile.backend
│   │   ├── Dockerfile.web
│   │   ├── Dockerfile.ai
│   │   └── docker-entrypoint.sh
│   │
│   ├── kubernetes/                # K8s manifests
│   │   ├── namespace.yaml
│   │   ├── configmap.yaml
│   │   ├── secrets.yaml
│   │   ├── pvc.yaml
│   │   ├── backend-deployment.yaml
│   │   ├── web-deployment.yaml
│   │   ├── postgres-deployment.yaml
│   │   ├── redis-deployment.yaml
│   │   ├── ai-deployment.yaml
│   │   ├── service-backend.yaml
│   │   ├── service-web.yaml
│   │   ├── ingress.yaml
│   │   └── hpa.yaml
│   │
│   ├── terraform/                # Infrastructure as Code (Optional)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── vpc.tf
│   │   ├── rds.tf
│   │   ├── s3.tf
│   │   ├── ecr.tf
│   │   └── iam.tf
│   │
│   ├── ci-cd/
│   │   ├── .github/workflows/
│   │   │   ├── backend-test.yml
│   │   │   ├── backend-build.yml
│   │   │   ├── web-build.yml
│   │   │   ├── mobile-build.yml
│   │   │   └── deploy.yml
│   │   └── gitlab-ci.yml
│   │
│   ├── monitoring/
│   │   ├── prometheus.yml
│   │   ├── grafana/
│   │   │   └── dashboards/
│   │   ├── alerting.yml
│   │   └── loki.yml
│   │
│   ├── logging/
│   │   ├── filebeat.yml
│   │   ├── logstash.conf
│   │   └── elasticsearch.yml
│   │
│   └── scripts/
│       ├── deploy.sh
│       ├── migrate.sh
│       ├── backup.sh
│       └── health-check.sh
│
├── docs/                           # Documentation
│   ├── ARCHITECTURE.md            # Architecture overview
│   ├── DATABASE_SCHEMA.md         # Database design
│   ├── API_DOCUMENTATION.md       # API reference
│   ├── DEPLOYMENT.md              # Deployment guide
│   ├── SETUP.md                   # Setup instructions
│   ├── DEVELOPMENT.md             # Development guide
│   ├── SECURITY.md                # Security practices
│   ├── TESTING.md                 # Testing strategy
│   ├── USER_GUIDES.md             # User documentation
│   └── TROUBLESHOOTING.md         # Troubleshooting guide
│
├── .env.example                    # Environment template
├── .gitignore
├── README.md                       # Project README
├── DEPLOYMENT.md                   # Deployment instructions
├── CONTRIBUTING.md                 # Contributing guidelines
├── LICENSE                         # License file
└── docker-compose.yml              # Root docker-compose for local dev
```

## Module Responsibilities

### Backend (FastAPI)
- REST API for all operations
- Authentication & authorization
- Database operations
- Business logic
- Integration with AI services
- Notification handling

### Mobile (Flutter)
- Employee attendance via face recognition
- GPS tracking
- Productivity analytics viewing
- Payslip management
- Profile management
- Push notifications

### Web Dashboard (Next.js)
- Admin/HR dashboard
- Real-time analytics
- Workforce management
- Payroll operations
- Reporting & exports
- System settings

### AI Services (Python)
- Face recognition inference
- Analytics computations
- Anomaly detection
- Predictive forecasting
- GPU-accelerated processing

### Infrastructure
- Container orchestration
- CI/CD pipelines
- Monitoring & alerting
- Logging & tracing
- Database management
- Cache management

## Key Files to Implement

### Priority 1 (Core)
- backend/main.py ✓
- backend/core/config.py ✓
- backend/core/database.py ✓
- backend/core/security.py ✓
- backend/services/face_recognition.py ✓
- Database schema migration
- API route implementations

### Priority 2 (Frontend)
- Flutter mobile app structure
- Next.js web dashboard structure
- Riverpod state management
- Zustand stores

### Priority 3 (DevOps)
- Docker containerization
- Kubernetes manifests
- CI/CD pipeline
- Monitoring setup

### Priority 4 (Polish)
- UI/UX refinements
- Performance optimization
- Security hardening
- Documentation completion
