# Automated Health Check System

This system monitors the health of a web application by performing periodic checks on a specified health endpoint. It logs results and sends alerts when issues are detected.


## Sample Slack Alert 

**Sample URL** "url": "https://ib1vjdrqg2qkgnjsi5g.c0.europe-west3.gcp.weaviate.cloud/v1/.well-known/live", "expected_status": 200

<img width="1189" alt="image" src="https://github.com/user-attachments/assets/ce8fe991-188b-46dc-9f87-6bc285b7878c" />


## Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/chsukhija/health-check-system.git
   cd health-check-system
   ```
   
2. **Build the Docker Image**

Run the following command to build the Docker image:

```bash
docker build -t health-check-system .
```

3. **Run the Docker Container**
Use the following command to run the container. Pass environment variables for configuration:

```bash
docker run -d \
  --env CHECK_INTERVAL=300 \
  --env RETRY_ATTEMPTS=3 \
  --env SLACK_TOKEN=xoxb-your-slack-bot-token \
  --env SLACK_CHANNEL="#health-checks" \
  health-check-system
```

3a. **Using Environment Variables**
If you prefer to use an .env file for environment variables, create a .env file:

```bash
# .env
CHECK_INTERVAL=300
RETRY_ATTEMPTS=3
SLACK_TOKEN=xoxb-your-slack-bot-token
SLACK_CHANNEL=#health-checks
Then, run the container with the .env file:
```

```bash
docker run -d --env-file .env health-check-system
```

4. **Verify the Container**
Check the logs to ensure the container is running correctly:

```bash
docker logs <container_id>
Example logs:

Copy
2025-03-08 07:27:13,422 - INFO - Health check for Astra Health https://www.datastax.com - Status: 200, Response Time: 0.41s
2025-03-08 07:27:13,423 - INFO - Health check for API Service https://status.astra.datastax.com/ - Status: 200, Response Time: 0.32s
```

5. **Stop and Remove the Container**
To stop and remove the container:

```bash
docker stop <container_id>
docker rm <container_id>
```




