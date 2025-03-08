import os
import json

# Load general configuration
CHECK_INTERVAL = int(os.getenv("CHECK_INTERVAL", "300").strip('"'))  # Default: 5 minutes
RETRY_ATTEMPTS = int(os.getenv("RETRY_ATTEMPTS", "3").strip('"'))  # Retry mechanism for transient failures

# Slack configuration
SLACK_TOKEN = os.getenv("SLACK_TOKEN", "").strip('"')  # Strip quotes
SLACK_CHANNEL = os.getenv("SLACK_CHANNEL", "#health-checks").strip('"')  # Strip quotes

# Load endpoints from environment variable
def load_endpoints():
    endpoints_json = os.getenv("ENDPOINTS", "[]")  # Default to an empty list
    try:
        return json.loads(endpoints_json)  # Parse JSON string
    except json.JSONDecodeError as e:
        logging.error(f"Failed to parse ENDPOINTS environment variable: {e}")
        return []
