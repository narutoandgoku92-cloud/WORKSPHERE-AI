# WorkSphere AI - Testing Guide

This guide covers how to run tests for the WorkSphere AI platform, including backend unit tests, integration tests, and Flutter widget tests.

---

## 🧪 Backend Testing

### Setup

```bash
# Navigate to backend directory
cd backend

# Create virtual environment (if not already done)
python -m venv venv
source venv/Scripts/activate  # Windows: venv\Scripts\activate

# Install test dependencies
pip install -r requirements.txt
pip install pytest pytest-asyncio pytest-cov
```

### Run All Tests

```bash
# Run all tests with verbose output
pytest -v

# Run with coverage report
pytest --cov=. --cov-report=html

# Run specific test file
pytest tests/test_auth.py -v

# Run specific test
pytest tests/test_auth.py::test_register_new_user -v

# Run tests matching a pattern
pytest -k "login" -v
```

### Test Organization

```
backend/tests/
├── conftest.py              # Pytest configuration and fixtures
├── test_auth.py             # Authentication tests (16 tests)
├── test_attendance.py       # Attendance tests (14 tests)
├── test_employees.py        # Employee management tests (optional)
├── test_analytics.py        # Analytics tests (optional)
└── __init__.py
```

### Markers

Run specific test categories:

```bash
# Run only unit tests
pytest -m unit

# Run only integration tests
pytest -m integration

# Run all except slow tests
pytest -m "not slow"
```

### Test Fixtures

Common fixtures available in `conftest.py`:

- `db_session`: In-memory SQLite database for testing
- `client`: FastAPI TestClient instance
- `admin_credentials`: Admin user credentials
- `test_user_data`: Sample user registration data
- `auth_headers`: Authenticated request headers

### Authentication Tests (16 tests)

**File**: `backend/tests/test_auth.py`

#### Registration (5 tests)
- ✅ `test_register_new_user` - Valid registration
- ✅ `test_register_duplicate_email` - Duplicate email fails
- ✅ `test_register_invalid_email` - Invalid email format fails
- ✅ `test_register_weak_password` - Weak password fails
- ✅ `test_register_missing_fields` - Missing required fields fails

#### Login (5 tests)
- ✅ `test_login_valid_credentials` - Valid credentials
- ✅ `test_login_invalid_email` - Non-existent email fails
- ✅ `test_login_wrong_password` - Wrong password fails
- ✅ `test_login_inactive_user` - Inactive user fails
- ✅ `test_login_missing_credentials` - Missing fields fails

#### Token Refresh (3 tests)
- ✅ `test_refresh_token_valid` - Valid token refresh
- ✅ `test_refresh_token_invalid` - Invalid token fails
- ✅ `test_refresh_token_missing` - Missing token fails

#### Password Change (3 tests)
- ✅ `test_change_password_valid` - Valid password change
- ✅ `test_change_password_wrong_old_password` - Wrong old password fails
- ✅ `test_change_password_weak_new_password` - Weak new password fails

#### Integration (1 test)
- ✅ `test_complete_auth_flow` - Full authentication cycle

### Attendance Tests (14 tests)

**File**: `backend/tests/test_attendance.py`

#### Check-In (5 tests)
- ✅ `test_check_in_valid` - Valid check-in
- ✅ `test_check_in_duplicate_today` - Duplicate same day fails
- ✅ `test_check_in_missing_location` - Missing location fails
- ✅ `test_check_in_invalid_coordinates` - Invalid coordinates fail
- ✅ `test_check_in_unauthorized` - No auth fails

#### Check-Out (3 tests)
- ✅ `test_check_out_valid` - Valid check-out
- ✅ `test_check_out_without_check_in` - No check-in fails
- ✅ `test_check_out_unauthorized` - No auth fails

#### Today's Stats (4 tests)
- ✅ `test_get_today_stats_checked_in` - Stats while checked in
- ✅ `test_get_today_stats_checked_out` - Stats when checked out
- ✅ `test_get_today_stats_not_checked_in` - No check-in status
- ✅ `test_get_today_stats_unauthorized` - No auth fails

#### History (1 test)
- ✅ `test_get_employee_attendance_history` - Get attendance history

#### Integration (1 test)
- ✅ `test_complete_attendance_flow` - Full attendance cycle

### Running Tests with Coverage

```bash
# Generate HTML coverage report
pytest --cov=. --cov-report=html

# View coverage report
open htmlcov/index.html  # macOS
start htmlcov/index.html # Windows
xdg-open htmlcov/index.html # Linux

# Show coverage in terminal
pytest --cov=. --cov-report=term-missing
```

### Test Output Example

```
tests/test_auth.py::test_register_new_user PASSED                    [  1%]
tests/test_auth.py::test_register_duplicate_email PASSED             [  2%]
tests/test_auth.py::test_login_valid_credentials PASSED              [  5%]
tests/test_attendance.py::test_check_in_valid PASSED                 [ 10%]
...
=============== 30 passed in 2.34s ===============
```

---

## 🔌 Integration Testing

### Setup Database for Integration Tests

```bash
# Use actual database (not in-memory)
export DATABASE_URL=postgresql://optiwork:optiwork_dev_password@localhost:5432/optiwork_test

# Run integration tests
pytest -m integration --tb=short
```

### Manual API Testing

Use the [API_TESTING_GUIDE.md](API_TESTING_GUIDE.md) for manual endpoint testing.

---

## 🎯 Flutter Widget Testing

### Setup

```bash
# Navigate to Flutter project
cd lib

# Get dependencies
flutter pub get

# Run tests
flutter test
```

### Run Specific Tests

```bash
# Run single test file
flutter test test/screens/login_screen_test.dart

# Run with verbose output
flutter test -v

# Run with coverage
flutter test --coverage
```

### Widget Test Example

**File**: `lib/screens/login_screen_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:work_sphere_ai/screens/login_screen.dart';
import 'package:work_sphere_ai/main.dart';

void main() {
  testWidgets('Login screen has email and password fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    
    // Verify fields exist
    expect(find.byType(TextField), findsWidgets);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
```

### Flutter Test Output

```
✓ test/screens/login_screen_test.dart: Login screen has email and password fields (52ms)
```

---

## 📊 Coverage Reports

### Backend Coverage Goals

- **Overall**: > 80%
- **Critical paths** (auth, attendance): > 90%
- **Utilities**: > 70%

### Current Coverage

Run to see current coverage:

```bash
pytest --cov=. --cov-report=term-missing | grep -E "^(.*|TOTAL)"
```

Expected output:
```
Name                          Stmts   Miss  Cover   Missing
------------------------------------------------------------
core/__init__.py                 2      0   100%
core/config.py                  42      3    93%   25-27,40
core/database.py                38      2    95%   51-53
api/v1/routes/auth.py           85      4    95%   120-123
api/v1/routes/attendance.py     120      6    95%   180-185
...
TOTAL                          2350    120    95%
```

---

## 🐛 Debugging Tests

### Print Debug Info

```python
# In test file
def test_something(client):
    response = client.post(...)
    print(f"Response: {response.json()}")  # Debug print
    assert response.status_code == 200
```

### Run with Full Output

```bash
# Show all print statements
pytest -s tests/test_auth.py::test_login_valid_credentials

# Show local variables on failure
pytest -l tests/test_auth.py

# Drop into pdb on failure
pytest --pdb tests/test_auth.py
```

### Verbose Mode

```bash
# Show test names and durations
pytest -v --durations=10

# Show fixtures
pytest --fixtures

# Show test collection
pytest --collect-only
```

---

## 🚀 CI/CD Integration

### GitHub Actions Example

Create `.github/workflows/tests.yml`:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_PASSWORD: password
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Set up Python
      uses: actions/setup-python@v2
      with:
        python-version: '3.11'
    
    - name: Install dependencies
      run: |
        pip install -r backend/requirements.txt
    
    - name: Run tests
      run: |
        cd backend
        pytest --cov=. --cov-report=xml
    
    - name: Upload coverage
      uses: codecov/codecov-action@v2
```

---

## 📋 Test Checklist

Before merging code, ensure:

- [ ] All tests pass: `pytest -v`
- [ ] Coverage > 80%: `pytest --cov=. --cov-report=term`
- [ ] No warnings: `pytest -v -W error`
- [ ] Linting passes: `flake8 .`
- [ ] Format correct: `black --check .`
- [ ] Types checked: `mypy .`

---

## 🔍 Common Issues

### Database Lock Error

```
sqlite3.OperationalError: database is locked
```

**Solution**: Clear test database:
```bash
rm -f test.db
pytest
```

### Import Errors

```
ModuleNotFoundError: No module named 'models'
```

**Solution**: Ensure `conftest.py` adds parent directory:
```python
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
```

### Async Test Failures

```
RuntimeError: no running event loop
```

**Solution**: Use `pytest-asyncio` marker:
```python
@pytest.mark.asyncio
async def test_async_function():
    ...
```

---

## 📚 Additional Resources

- [Pytest Documentation](https://docs.pytest.org/)
- [FastAPI Testing](https://fastapi.tiangolo.com/advanced/testing-dependencies/)
- [Flutter Testing](https://flutter.dev/docs/testing)
- [Code Coverage](https://coverage.readthedocs.io/)

---

## 🎯 Test Goals

- **Stability**: Reliable, deterministic tests
- **Speed**: Fast test execution (< 5 seconds)
- **Coverage**: Critical paths 100% covered
- **Maintainability**: Clear, well-documented tests
- **Independence**: Tests don't depend on each other

---

**Last Updated**: 2024
**Status**: Production Ready
