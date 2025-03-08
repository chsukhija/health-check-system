import os
import json

# Load endpoints from JSON file
def load_endpoints():
    with open("endpoints.json", "r") as file:
        return json.load(file)

# General configuration
CHECK_INTERVAL = int(os.getenv("CHECK_INTERVAL", "300").strip('"'))  # Default: 5 minutes
RETRY_ATTEMPTS = int(os.getenv("RETRY_ATTEMPTS", "3").strip('"'))  # Retry mechanism for transient failures

# Slack configuration
SLACK_TOKEN = os.getenv("SLACK_TOKEN", "").strip('"')  # Strip quotes
SLACK_CHANNEL = os.getenv("SLACK_CHANNEL", "#health-checks").strip('"')  # Strip quotes
