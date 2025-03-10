# Automated Health Check System

This system monitors the health of a web application by performing periodic checks on a specified health endpoint. It logs results and sends alerts when issues are detected.


## Sample Slack Alert 

**Sample URL** "url": "https://ib1vjdrqg2qkgnjsi5g.c0.europe-west3.gcp.weaviate.cloud/v1/.well-known/live", "expected_status": 200

<img width="1152" alt="image" src="https://github.com/user-attachments/assets/3a9fceb6-ef27-4f44-9cf6-a8d77adde3f7" />



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

3a. **Using Environment Variables**
Use the following command to run the container. Pass environment variables for configuration:

```bash
docker run -d \
  --env CHECK_INTERVAL=300 \
  --env RETRY_ATTEMPTS=3 \
  --env SLACK_TOKEN=xoxb-your-slack-bot-token \
  --env SLACK_CHANNEL="#health-checks" \
  health-check-system
```

3b. **Using Environment Variables in .env file**
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

2025-03-10 06:40:19,688 - INFO - Starting health check system...

2025-03-10 06:40:20,563 - INFO - Health check for DataStax Astra Health (https://95f92980-d23d-45c6-9185-3e036d3058f0-europe-west4.apps.astra.datastax.com/api/rest/health) - Status: 200, Response Time: 0.87s

2025-03-10 06:40:21,056 - ERROR - Alert sent to Slack: https://95f92980-d23d-45c6-9185-3e036d3058f0-europe-west4.apps.astra.datastax.com/api/rest/health: Passed: UP

2025-03-10 06:40:21,622 - INFO - Health check for API Service (https://ib1vjdrqg2qkgnjsi5g.c0.europe-west3.gcp.weaviate.cloud/v1/.well-known/live) - Status: 200, Response Time: 0.56s

2025-03-10 06:40:22,064 - ERROR - Alert sent to Slack: https://ib1vjdrqg2qkgnjsi5g.c0.europe-west3.gcp.weaviate.cloud/v1/.well-known/live: Passed: 
```

5. **Stop and Remove the Container**
To stop and remove the container:

```bash
docker stop <container_id>
docker rm <container_id>
```




