# Instructions for bookie.test Project Setup

## 1. Project Goal & Requirements

This setup aims to create a functional base Laravel 11 application within the `./bookie.test/` directory, using Docker containers defined and orchestrated by files located within *this* directory (`host.scripts/`).

The primary objective is to **build a small REST API for a Booking System**.

### Core Functionality Required:

*   Full CRUD operations for the `Booking` entity.
*   Association between `Booking` and a `Customer` entity.
*   Input validation using Laravel Form Requests.
*   Authentication middleware (Laravel Sanctum or simple token).
*   Logging of significant operations.
*   An API endpoint for CSV export of bookings.

### Technical Requirements:

*   **Framework:** Laravel 11+
*   **Language:** PHP 8.3+
*   **Architecture:** Service Layer or Action Classes, Repository Pattern.
*   **Design Patterns:** Apply where useful (e.g., Strategy, Factory).
*   **Code Quality:** Linting via PHP-CS-Fixer or Laravel Pint.
*   **Static Analysis:** PHPStan (Level 5+ recommended).
*   **Testing:** PHPUnit.
*   **Environment:** Must run via Docker (PHP/Laravel + MySQL/PostgreSQL).

## 2. Directory Structure Reference

The canonical file structure is documented in `./bookie.test/files.tree.0.md`. **Do not modify or delete `files.tree.0.md`**. A backup may exist at `files.tree.0.bkp.md`, but `files.tree.0.md` is the source of truth.

Key points of the structure:
*   **`./bookie.test/` (Parent Directory):**
    *   Contains `files.tree.0.md`.
    *   Is the **target location** for the generated Laravel application files (e.g., `app/`, `bootstrap/`, `public/`, `.env`). These files exist **only inside the container** at `/app` due to the container-only setup.
    *   Contains the `host.scripts/` directory.
*   **`./bookie.test/host.scripts/` (This Directory):**
    *   Contains the master setup script: `setup.sh`.
    *   Contains the Docker build file: `Dockerfile`.
    *   Contains the Docker service definitions: `docker-compose.yml`.
    *   Contains modular installation/configuration scripts:
        *   `install.p1.mysql.etc.sh` (APT packages, time sync)
        *   `install.p2.laravel.etc.sh` (Composer create-project)
        *   `configure.p3.laravel.etc.sh` (Laravel permissions, .env config, key gen, migrations)
    *   Contains utility scripts: `backup_*.sh`, `check_test.sh`.

## 3. How to Run the Setup

1.  **Navigate** to this directory:
    ```bash
    cd ./bookie.test/host.scripts
    ```
2.  **Ensure** `setup.sh` is executable:
    ```bash
    chmod +x setup.sh
    ```
3.  **Execute** the setup script:
    ```bash
    ./setup.sh
    ```

## 4. Development Workflow Principles

*   **CORE PROJECT RULE (MOST IMPORTANT): Dockerfile Usage & Command Execution**
    *   **Dockerfile Role:** The `Dockerfile` (or `Dockerfile.restore`) is used **only** to define the base environment (OS, PHP, base packages) or to layer pre-existing application state from a backup. It **must never** contain application startup logic (`CMD`, `ENTRYPOINT`) intended to run the Laravel server or related services automatically.
    *   **Command Execution:** All commands related to application management (installing dependencies, running migrations, starting/stopping servers, clearing caches, running tests, etc.) **must** be executed via `docker exec bookie-test-app [command]` from the host *after* the container has been started (typically via `load_and_start.sh`). Treat the running container like a standard OS accessed via `docker exec`.
    *   **Internal Automation:** If automation *inside* the container is needed (e.g., delayed start, monitoring), it must be implemented using tools like `supervisor` which are installed via `docker exec` and **manually started** via `docker exec` (e.g., `docker exec -d bookie-test-app supervisord -c ...`).

*   **Task Execution:** Follow tasks outlined in `readme.tasks.md`.
*   **Container Interaction (Default Procedure):**
    *   **Environment Basis:** Start from a known-good container state loaded from a saved image archive (`.tar.gz`) using `load_and_start.sh`.
    *   **Manual Shell Access:** Use `docker exec -it bookie-test-app bash` for interactive work.
    *   **Adding/Modifying Files (CRITICAL RULE):**
        1.  Create/edit file locally on host with full content.
        2.  Use `docker cp <local> <container>:<path>` to overwrite file inside container.
        3.  Use `docker exec ... chmod ...` for permissions if needed.
    *   **File Editing Rule (CRITICAL):** Never attempt partial file edits.
    *   **Avoid:** Complex multi-line `docker exec` for file creation.
*   **Verification:** Verify changes via `docker exec` or browser access.
*   **Saving State:** Use `./bookie.bkp/commit_and_save_state.sh [tag]` to commit running container state.
*   **Logging:** Update `readme.tasks.md`.

## 5. `setup.sh` Workflow Explanation

The `setup.sh` script orchestrates the initial environment setup:
1.  Changes directory to the parent (`./bookie.test/`).
2.  Cleans up previous Docker runs and old Laravel files in the parent directory, **preserving** `host.scripts/`, `.git/` (if exists), and `files.tree.0.md`.
3.  Uses `docker-compose.yml` (from *this* directory, `host.scripts/`) to build the image defined by `Dockerfile` (also from *this* directory) and start the `test-app` and `test-db` containers. The build context for Docker is set to *this* directory (`host.scripts/`).
4.  The `Dockerfile` copies the install/config scripts from the build context into `/usr/local/bin/` inside the image.
5.  `setup.sh` then executes the following scripts sequentially *inside* the running `test-app` container (working directory `/app`) using `docker-compose exec`:
    *   `install.p1.mysql.etc.sh` (Installs system packages)
    *   `install.p2.laravel.etc.sh` (Installs Laravel using Composer directly into `/app`)
    *   `configure.p3.laravel.etc.sh` (Configures the installed Laravel application in `/app`)

## 6. Expected Outcome (Post-Setup)

After `setup.sh` completes successfully:
*   Docker containers `bookie-test-app` and `bookie-test-db` will be running.
*   A complete Laravel 11 application structure will exist *inside the container* at `/app`.
*   The Laravel application will be configured to connect to the `test-db` container.
*   Default Laravel database migrations will have been run.

## 7. Important Notes

*   The Laravel application files reside **only inside the container** at `/app`. They are **not** mirrored on the host filesystem due to the removal of the volume mount in `docker-compose.yml`.
*   To interact with the application (e.g., run `php artisan` commands), use `docker-compose exec` from this directory (`host.scripts/`):
    ```bash
    docker-compose -f docker-compose.yml -p booki_test exec test-app [your command]
    # Example: docker-compose -f docker-compose.yml -p booki_test exec test-app php artisan list
    ```
*   All setup orchestration and configuration files (`Dockerfile`, `docker-compose.yml`, `.sh` scripts) are managed within this `host.scripts/` directory.

## 8. Backup Log

*   **[2025-04-27 02:15 UTC Approx]** Container state committed and saved.
    *   **Image Tag:** `bookie-test-app_backup:20250426_221546_[RANDOM_ID]` (Kept Locally)
    *   **Archive File:** `./bookie.bkp/bookie-test-app.bkp.20250426_221546_[RANDOM_ID].tar.gz`
    *   *(Note: RANDOM_ID in actual filenames might differ slightly due to script execution timing)* 