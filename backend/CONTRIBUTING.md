# Contributing to MicroClimate Backend

Thank you for your interest in contributing to the MicroClimate AI Pro Backend! This document provides guidelines to help you get started.

## 🎯 Before You Start

- Read the [README.md](README.md) to understand the project structure and architecture
- Check existing [Issues](https://github.com/yourusername/microclimate-backend/issues) to avoid duplicates
- For large changes, open an issue first to discuss your approach

## 🔧 Development Setup

### Prerequisites
- Python 3.12+
- PostgreSQL 16
- Docker & Docker Compose (optional)

### Local Environment Setup

```bash
# Clone repository
git clone https://github.com/yourusername/microclimate-backend.git
cd microclimate-backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install development dependencies
pip install -r requirements.txt

# Setup pre-commit hooks (optional but recommended)
pip install pre-commit
pre-commit install
```

### Configuration

```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your local settings
# For development, you can use:
# - Local PostgreSQL or docker-compose postgres
# - Your MQTT broker credentials
```

### Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app

# Run specific test file
pytest tests/test_climate.py -v
```

### Code Quality

```bash
# Format code
black app/

# Sort imports
isort app/

# Lint
flake8 app/ --max-line-length=100

# Type checking
mypy app/
```

## 📝 Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

Use descriptive branch names:
- `feature/add-mqtt-reconnection`
- `fix/websocket-memory-leak`
- `docs/improve-api-docs`

### 2. Make Your Changes

- Write clean, readable code
- Add docstrings to functions and classes
- Include type hints
- Update relevant tests

### 3. Commit with Clear Messages

```bash
git commit -m "Add feature: Brief description

- Detailed bullet points
- Explaining changes made
- Reference issue numbers: Fixes #123"
```

Commit message format:
```
[Type]: Brief description

Detailed explanation (optional)

Fixes #issue-number (if applicable)
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### 4. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a pull request on GitHub with:
- Clear title and description
- Link to relevant issues
- Screenshots/logs if applicable
- Checklist:
  - [ ] Tests pass
  - [ ] Code is linted
  - [ ] Documentation updated
  - [ ] No breaking changes (or documented)

## 📋 Code Style Guidelines

### Python Style
- Follow [PEP 8](https://pep8.org/)
- Use type hints: `def function(param: str) -> int:`
- Max line length: 100 characters
- Use f-strings for formatting: `f"Value: {var}"`

### Docstrings

```python
def process_sensor_data(data: Dict[str, float]) -> Dict[str, Any]:
    """Process raw sensor data and generate forecasts.
    
    Validates input data and applies Holt-Winters forecasting model
    to predict future values.
    
    Args:
        data: Sensor readings with temperature, humidity, CO2, CO keys
        
    Returns:
        dict: Processed data with forecasts and emergency alerts
        
    Raises:
        ValueError: If data format is invalid
        
    Example:
        >>> result = process_sensor_data({
        ...     'temperature': 22.5,
        ...     'humidity': 45.0
        ... })
    """
```

### Imports Organization

```python
# Standard library
import asyncio
import json
from datetime import datetime
from typing import Dict, List, Optional

# Third-party
import asyncpg
import paho.mqtt.client as mqtt
from fastapi import APIRouter, Depends

# Local imports
from ..config import settings
from ..core.database import db
```

## 🧪 Testing Guidelines

### Test File Structure
- Place tests in `tests/` directory
- Name test files: `test_module_name.py`
- Name test functions: `test_specific_behavior()`

### Writing Tests

```python
import pytest
from app.services.ai_service import AIService

class TestAIService:
    """Test suite for AI forecasting service."""
    
    def test_predict_holt_basic(self):
        """Test Holt-Winters prediction with simple data."""
        data = [20.0, 21.0, 22.0, 21.5, 23.0]
        result = AIService.predict_holt(data, steps_ahead=1)
        
        assert isinstance(result, float)
        assert 20.0 < result < 25.0
    
    @pytest.mark.asyncio
    async def test_database_connection(self):
        """Test async database connection."""
        await db.connect()
        assert db.pool is not None
        await db.disconnect()
```

## 🐛 Bug Reports

When reporting bugs, please include:

1. **Description**: What did you expect vs what happened?
2. **Steps to Reproduce**: Exact steps to trigger the bug
3. **Environment**: 
   - OS (Windows/Linux/Mac)
   - Python version
   - FastAPI/dependency versions
4. **Logs**: Relevant error messages and stack traces
5. **Attachments**: Screenshots, JSON payloads, etc.

## 💡 Feature Requests

Describe your feature with:

1. **Problem Statement**: What problem does it solve?
2. **Proposed Solution**: How would you implement it?
3. **Alternatives Considered**: Other approaches?
4. **Implementation Effort**: Small/Medium/Large?
5. **Breaking Changes**: Does it break existing functionality?

## 📚 Documentation

When adding features, update:

- `README.md` - If user-facing changes
- API docstrings - All endpoints
- Configuration comments - New env variables
- CHANGELOG.md - Summary of changes

## 🔐 Security

- Never commit credentials or secrets
- Use environment variables for configuration
- Review code for potential vulnerabilities
- Run security checks: `bandit -r app/`

## 📞 Getting Help

- Open an issue with the `question` label
- Check existing discussions and closed issues
- Ask in the repository discussions section

## 🎓 Project Resources

- **Architecture Docs**: See README.md sections
- **API Reference**: http://localhost:8000/docs
- **Database Schema**: `db/*.sql` files
- **AI Algorithm**: See `services/ai_service.py` docstrings

## ✅ Before Submitting PR

- [ ] Code follows style guidelines
- [ ] All tests pass (`pytest`)
- [ ] Code is linted (`black`, `flake8`)
- [ ] Type hints are correct (`mypy`)
- [ ] Docstrings are complete
- [ ] No breaking changes (or documented)
- [ ] README updated (if needed)
- [ ] Commit messages are clear

## 🎉 Thank You!

Your contributions help make MicroClimate better for everyone. Whether it's code, documentation, or bug reports, we appreciate your involvement!

---

**Questions?** Open an issue or start a discussion. We're here to help!
