#!/bin/bash
# start_dockerhub_pipeline.sh
# -----------------------------------------------------------------------------
# Pulls a specific image from Docker Hub, starts the container, 
# and then MANUALLY starts supervisor inside it.
# Based on start_docker_pipeline.sh but uses docker pull/run instead of load.
# -----------------------------------------------------------------------------

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
# Define the image to pull from Docker Hub
DOCKERHUB_IMAGE="user987987/bookie-supervisor-manual:latest"

CONTAINER_NAME="bookie-test-app" # Must match the name expected by later steps
SUPERVISOR_CONF="/etc/supervisor/supervisord.conf" # Path inside the container
# --- End Configuration ---

# Ensure script is run from its own directory (host.scripts)
cd "$(dirname "$0")" || { echo "Error: Failed to change directory to script location." >&2; exit 1; }
echo "Running script from: $(pwd)"

echo "--- Starting Docker Hub Pipeline (Manual Supervisor Trigger) --- "

# --- Step 1: Pull Image and Start Container ---
echo "[Step 1/4] Pulling image '${DOCKERHUB_IMAGE}' from Docker Hub..."
if ! docker pull "${DOCKERHUB_IMAGE}"; then
    echo "Error: Failed to pull image '${DOCKERHUB_IMAGE}' from Docker Hub." >&2
    exit 1
fi
echo "  - Image pulled successfully."

echo "[Step 2/4] Stopping and removing any existing container named '${CONTAINER_NAME}'..."
docker stop "${CONTAINER_NAME}" > /dev/null 2>&1 || true
docker rm "${CONTAINER_NAME}" > /dev/null 2>&1 || true
echo "  - Cleanup complete."

echo "[Step 3/4] Starting new container '${CONTAINER_NAME}' from image '${DOCKERHUB_IMAGE}'..."
# Run detached, assign name, use the pulled image.
# Use 'tail -f /dev/null' as the command to keep the container running idly.
# Add port mappings here if needed, e.g., -p 8001:8001
if ! docker run -d --name "${CONTAINER_NAME}" -p 8001:8001 "${DOCKERHUB_IMAGE}" tail -f /dev/null; then
    echo "Error: Failed to start container '${CONTAINER_NAME}' from image '${DOCKERHUB_IMAGE}'." >&2
    exit 1
fi
echo "  - Container started successfully in detached mode."

# --- Step 2 renamed to 4 --- 
echo "[Step 4/4] Waiting for container to settle..."
sleep 10 # Give container time to initialize

# --- Step 3 & Verification remain similar --- 
# Check if container is actually running before trying to exec
if ! docker ps -q -f name="^/${CONTAINER_NAME}$"; then
    echo "Error: Container '${CONTAINER_NAME}' did not start correctly or exited prematurely." >&2
    exit 1
fi
echo "Container '${CONTAINER_NAME}' confirmed running."

echo "Pipeline Step: Manually starting supervisord inside container..."
if ! docker exec -d "${CONTAINER_NAME}" /usr/bin/supervisord -c "${SUPERVISOR_CONF}"; then
    echo "Error: Failed to execute supervisord start command in container '${CONTAINER_NAME}'." >&2
    exit 1
fi
echo "Supervisord start command issued via docker exec."

echo "--- Docker Hub Pipeline Finished --- "
echo "Supervisord started manually inside container '${CONTAINER_NAME}'."
echo "It should launch Laravel after internal delays."
echo "Check status with: docker exec ${CONTAINER_NAME} supervisorctl status"
echo "Application may be available shortly (check container logs/ports)."

exit 0 