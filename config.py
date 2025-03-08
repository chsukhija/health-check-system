import os

# Health check configuration
HEALTH_ENDPOINT = os.getenv("HEALTH_ENDPOINT", "http://example.com/health")
CHECK_INTERVAL = int(os.getenv("CHECK_INTERVAL", "300").strip('"'))  # Strip quotes and convert to int
RESPONSE_TIME_THRESHOLD = float(os.getenv("RESPONSE_TIME_THRESHOLD", "3.0").strip('"'))  # Strip quotes and convert to float
RETRY_ATTEMPTS = int(os.getenv("RETRY_ATTEMPTS", "3").strip('"'))  # Strip quotes and convert to int

# Slack configuration
SLACK_TOKEN = os.getenv("SLACK_TOKEN", "").strip('"')  # Strip quotes
SLACK_CHANNEL = os.getenv("SLACK_CHANNEL", "#health-checks").strip('"')  # Strip quotes
