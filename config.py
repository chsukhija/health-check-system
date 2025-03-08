import os

# Configuration settings
HEALTH_ENDPOINT = os.getenv("HEALTH_ENDPOINT", "http://example.com/health")
CHECK_INTERVAL = int(os.getenv("CHECK_INTERVAL", 300))  # Default: 5 minutes
RESPONSE_TIME_THRESHOLD = float(os.getenv("RESPONSE_TIME_THRESHOLD", 3.0))  # Default: 3 seconds
RETRY_ATTEMPTS = int(os.getenv("RETRY_ATTEMPTS", 3))  # Retry mechanism for transient failures
