import os

# Health check configuration
HEALTH_ENDPOINT = os.getenv("HEALTH_ENDPOINT", "https://weaviate.io/")
CHECK_INTERVAL = int(os.getenv("CHECK_INTERVAL", 300))  # Default: 5 minutes
RESPONSE_TIME_THRESHOLD = float(os.getenv("RESPONSE_TIME_THRESHOLD", 3.0))  # Default: 3 seconds
RETRY_ATTEMPTS = int(os.getenv("RETRY_ATTEMPTS", 3))  # Retry mechanism for transient failures

# Slack configuration
SLACK_TOKEN = os.getenv("SLACK_TOKEN")  # Slack bot token
SLACK_CHANNEL = os.getenv("SLACK_CHANNEL", "#health-checks")  # Slack channel to send alerts
