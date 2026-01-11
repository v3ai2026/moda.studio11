# moda.studio11 — Copilot Instructions

These instructions help AI coding agents understand and productively contribute to the moda.studio11 codebase. They document actual architecture, workflows, and patterns found in production code.

## Big Picture

**Dual-stack architecture**: moda.studio11 splits across two services:
- **Laravel backend** (`server/` is authoritative). Handles web UI, REST APIs, AI tools, chatbots, payments, extensions, and admin dashboard. Framework: Laravel 10. **Always work in `server/`.**
- **Python backend service** (`backend-service/`): Standalone Flask microservice for Vertex AI customer service (GCP Gemini integration). Runs on port 8080; connected via env var `VERTEX_AI_BACKEND_URL`.
- **Database**: MySQL with 60+ tables (magicai.sql). All tables use InnoDB, utf8mb4_unicode_ci, created_at/updated_at. Can be imported directly: `mysql -u user -p < magicai.sql`.
- **Extensibility**: Extensions as ZIPs in `extensions/` (each with extension.json, optional database/, resources/, System/). Themes in `themes/`.
- **Package-based architecture**: Core features live in `server/packages/` (magicai-updater, magicai-healthy, installer, openai-php). These are local Composer repositories.

## Laravel Application (server/)

**Framework**: Laravel 10. Key Composer dependencies: AWS SDK, Stripe, PayPal, Mailchimp, Google APIs, Telegram SDK, OpenAI/Anthropic/Azure/Vertex AI SDKs. Built-in packages from `packages/` provide installer, health checks, and AI client bindings.

**Directory structure**:
- `app/Http/Controllers/Api/`: API endpoints organized by feature. Inject services; return JSON.
- `app/Services/Ai/`: AI tool management (AiToolService). Provider abstractions and multi-provider support.
- `app/Models/`: Eloquent models with relationships and $casts for type safety.
- `routes/api.php`: RESTful `/api/{resource}/{action}`. Auth middleware: `auth:api`.
- `database/migrations/`: Schema changes. Apply with `php artisan migrate`.
- `resources/views/`: Per-theme directories. Vite compiles SCSS/JS.
- `packages/magicai/magicai-updater/`: Automated version upgrades.
- `packages/magicai/magicai-healthy/`: Health checks, extension validation.

## Data Model

**Critical tables**:
- **app_settings**: Global config (API keys as JSON).
- **engines**: AI provider toggles (openai, anthropic, gemini, azure, fal_ai). Status: enabled/disabled.
- **entities**: Available models per engine.
- **ai_tools**: Tool metadata, category, pricing, parameters.
- **ai_tool_usage**: Usage tracking and credit deduction.
- **users, plans, subscriptions**: Auth and billing.
- **gateways, gateway_products**: Multi-payment support.

**Database conventions**:
- Status fields: Use strings (enabled/disabled, active/inactive), not booleans.
- JSON fields: Always use json_valid(...) constraint.
- Foreign keys named {table}_id; cascade delete where appropriate.

## Service Architecture

**Key services**:
- **AiToolService** (`app/Services/Ai/AiToolService.php`): AI tool registry and execution. Manages tool parameters, pricing, provider routing.
- **Payment/**: Payment processing, credit deduction, multi-gateway support.
- **Extension/**: ZIP extraction, license validation, DB migration running.
- **Theme/**: Theme loading, asset compilation.

## Python Backend Service (backend-service/)

**Framework**: Flask microservice for Vertex AI integration. Handles chat requests from Laravel via HTTP.

**Key patterns**:
- **Initialization**: Vertex AI initialized at startup via `aiplatform.init(project=PROJECT_ID, location=REGION)`. Requires `GCP_PROJECT_ID`, `GCP_REGION` env vars.
- **Caching**: In-memory cache with TTL (default 3600s). Used to deduplicate identical questions.
- **Rate limiting**: Per-client (IP-based) rate limiter. Default 60 requests/min.
- **Request format**: POST /api/chat with `{"question": "...", "history": [...]}`. Returns `{"answer": "...", "cached": true/false}`.
- **Error handling**: HTTP 429 for rate limit; 500 for Vertex AI errors.

**Local run**: `python app.py` (port 8080). Requires GCP credentials and Gemini API access.

## Developer Workflows

**Local setup**:
```bash
# Laravel (server/)
cd server
composer install
npm install
cp .env.mdio.example .env
php artisan key:generate
npm run dev  # Watch mode

# Python backend (backend-service/)
cd ../backend-service
python3 -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install -r requirements.txt
python app.py  # Runs on port 8080
```

**Docker setup**:
```bash
docker compose up  # Starts all services: MySQL, Redis, Laravel (port 8000), Python backend (port 8080)
```

**Testing**:
```bash
php artisan test              # Run PHPUnit tests
php artisan test --filter=Foo # Run specific test
```

**Useful commands**:
```bash
php artisan migrate            # Apply migrations
php artisan tinker             # Interactive shell
php artisan cache:clear        # Clear caches
php artisan make:controller Foo # Create controller
npm run build                  # Production frontend build
```

## Code Patterns

**Adding AI tool**:
1. Add row to ai_tools table.
2. Create AiToolController method or use AiToolService.
3. Service handles provider routing, parameter validation, credit deduction.

**Adding API endpoint**:
1. Create controller in `app/Http/Controllers/Api/`.
2. Define route in `routes/api.php`.
3. Inject services; return JSON.

**Enabling AI provider**:
1. Add row to engines table (status='enabled').
2. Add model rows to entities table.
3. Create provider handler in AiToolService.

**Extension installation**:
1. Admin uploads ZIP to extensions/.
2. ExtensionService extracts, validates extension.json.
3. Database migrations run (if database/migration.sql exists).
4. Routes registered dynamically.

## Important Conventions

**Configuration**:
- App settings stored in app_settings table.
- Provider toggles in engines table.
- Provider models in entities table.

**Status fields**: Never use booleans — use string enums (enabled/disabled, active/inactive, pending/completed).

**JSON fields**: Always decode safely; handle null.

**Cross-service communication**:
- Laravel calls Python backend via HTTP (env var VERTEX_AI_BACKEND_URL).
- No shared database; each service owns its schema.
- Handle network timeouts gracefully with retry logic.

## File Structure

```
server/
├── app/Http/Controllers/Api/        # API endpoints
├── app/Services/Ai/                 # AI tool management
├── app/Models/                      # Eloquent models
├── routes/api.php                   # API routes
├── database/migrations/             # Schema changes
├── resources/views/                 # Blade templates
└── packages/magicai/                # Local packages

backend-service/
├── app.py                           # Flask entry point
├── requirements.txt                 # Python dependencies
└── Dockerfile

extensions/                          # Pluggable features
└── {ExtensionName}/
    ├── extension.json
    ├── database/
    ├── resources/
    └── System/

magicai.sql                          # Database schema & seed
```

## Deployment (5-Endpoint Architecture)

### 1. Database Endpoint (MySQL/MariaDB)
- **Setup**: `mysql -u user -p -h <DB_HOST> < magicai.sql`
- **Env vars**: `DB_CONNECTION=mysql`, `DB_HOST`, `DB_PORT=3306`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`.

### 2. Laravel Frontend Endpoint (server/public)
- **Setup**:
  ```bash
  cd server
  composer install --no-dev
  npm install && npm run build
  php artisan key:generate
  php artisan config:cache
  php artisan storage:link
  ```
- **Env vars**: `APP_URL`, `APP_KEY`, `SESSION_DOMAIN`, `SANCTUM_STATEFUL_DOMAINS`.

### 3. Python Backend Endpoint (Flask port 8080)
- **Setup**:
  ```bash
  cd backend-service
  python3 -m venv venv && source venv/bin/activate
  pip install -r requirements.txt
  python app.py
  ```
- **Env vars**: `GCP_PROJECT_ID`, `GCP_REGION`, `MODEL_ID=gemini-2.0-flash`, `PORT=8080`.
- **Laravel config**: Set `VERTEX_AI_BACKEND_URL=http://localhost:8080`.

### 4. Redis Cache Endpoint (Optional)
- **Env vars**: `CACHE_DRIVER=redis`, `REDIS_HOST`, `REDIS_PORT=6379`, `REDIS_PASSWORD`.
- **Fallback**: `CACHE_DRIVER=file` (slower).

### 5. Extensions & Themes Endpoint (extensions/, themes/)
- Admins upload ZIPs via dashboard; system validates and activates.

**Docker**: `docker compose up -d` (uses docker-compose.yml).

## Common Gotchas

**Path confusion**: Always use `server/` (authoritative), not legacy directories.

**Missing VERTEX_AI_BACKEND_URL**: Breaks Vertex AI integration. Set early in setup.

**GCP credentials**: Python backend requires valid GCP service account. Ensure `GCP_PROJECT_ID` matches your project.

**Status fields**: Use string enums, not booleans. Check `engines.status`, `ai_tool.status`.

**Cross-service timeouts**: Implement retry logic with exponential backoff (30s timeout recommended).

**Extension loading**: Invalid PHP in System/* breaks entire app. Validate syntax before activation.

**Database migrations**: For deployments, prefer importing magicai.sql directly (faster, consistent).

## Documentation & References

- Database schema: magicai.sql is authoritative.
- Integration guides: AI_TOOLS_INTEGRATION.md, CUSTOMER_SERVICE_INTEGRATION.md.
- Deployment: server/DEPLOY.md, backend-service/README.md.
- Laravel docs: https://laravel.com/docs/10.x
  - Types: feat, fix, docs, style, refactor, test, chore

## Code Conventions
- **Language**: To be determined
- **Formatting**: Define linting and formatting rules as project grows
- **File Organization**: Create consistent directory structure for code, tests, and assets
- **Naming Conventions**: Document patterns for functions, classes, variables per language choice

## Important Notes for AI Agents
- This is a greenfield project - establish patterns early for consistency
- All future documentation should be placed in `/.github/copilot-instructions.md`
- Reference specific examples in the codebase (file paths, function names) when describing patterns
- Focus on discoverable patterns, not aspirational practices

## Getting Started
When the first significant code is committed:
1. Update this file with actual architecture details
2. Reference key files that exemplify important patterns
3. Document project-specific conventions that differ from common practices
4. Include specific commands for builds, tests, and debugging

---

**Last Updated**: 2026-01-11  
**Status**: Template - awaiting initial project structure
