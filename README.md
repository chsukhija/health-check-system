# Automated Health Check System

This system monitors the health of a web application by performing periodic checks on a specified health endpoint. It logs results and sends alerts when issues are detected.

## Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/chsukhija/health-check-system.git
   cd health-check-system
   
**Build the Docker Image**

Run the following command to build the Docker image:

```bash
docker build -t health-check-system .

**Run the Docker Container**
Use the following command to run the container. Pass environment variables for configuration:

```bash
docker run -d \
  --env CHECK_INTERVAL=300 \
  --env RETRY_ATTEMPTS=3 \
  --env SLACK_TOKEN=xoxb-your-slack-bot-token \
  --env SLACK_CHANNEL="#health-checks" \
  health-check-system

**Using Environment Variables**
If you prefer to use an .env file for environment variables, create a .env file:

```bash
# .env
CHECK_INTERVAL=300
RETRY_ATTEMPTS=3
SLACK_TOKEN=xoxb-your-slack-bot-token
SLACK_CHANNEL=#health-checks
Then, run the container with the .env file:

```bash
docker run -d --env-file .env health-check-system

**Verify the Container**
Check the logs to ensure the container is running correctly:

```bash
docker logs <container_id>
Example logs:

Copy
2025-03-08 07:27:13,422 - INFO - Health check for Weaviate Health (https://weaviate.io/health) - Status: 200, Response Time: 0.41s
2025-03-08 07:27:13,423 - INFO - Health check for API Service (https://api.example.com/status) - Status: 200, Response Time: 0.32s

**Stop and Remove the Container**
To stop and remove the container:

```bash
docker stop <container_id>
docker rm <container_id>
