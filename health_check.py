import requests
import time
import logging
from config import HEALTH_ENDPOINT, CHECK_INTERVAL, RESPONSE_TIME_THRESHOLD, RETRY_ATTEMPTS

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("logs/health_check.log"),
        logging.StreamHandler()
    ]
)

# Mock alerting function
def send_alert(message):
    """
    Simulates sending an alert (e.g., email, Slack).
    """
    logging.error(f"ALERT: {message}")
    # In a real-world scenario, integrate with an alerting service like Twilio, Slack, or PagerDuty.

def check_health():
    """
    Performs a health check on the configured endpoint.
    """
    for attempt in range(RETRY_ATTEMPTS):
        try:
            start_time = time.time()
            response = requests.get(HEALTH_ENDPOINT, timeout=5)
            response_time = time.time() - start_time

            # Log response details
            logging.info(f"Health check for {HEALTH_ENDPOINT} - Status: {response.status_code}, Response Time: {response_time:.2f}s")

            # Check response time
            if response_time > RESPONSE_TIME_THRESHOLD:
                logging.warning(f"Response time exceeded threshold: {response_time:.2f}s > {RESPONSE_TIME_THRESHOLD}s")

            # Check HTTP status code
            if response.status_code != 200:
                send_alert(f"Non-200 status code: {response.status_code}")

            # Optionally parse response body for health indicators
            if response.status_code == 200:
                health_data = response.json()
                if health_data.get("database_status") != "ok":
                    send_alert(f"Database connectivity issue: {health_data.get('database_status')}")

            break  # Exit retry loop if successful

        except requests.exceptions.RequestException as e:
            logging.error(f"Attempt {attempt + 1} failed: {e}")
            if attempt == RETRY_ATTEMPTS - 1:
                send_alert(f"Health check failed after {RETRY_ATTEMPTS} attempts: {e}")
            time.sleep(5)  # Wait before retrying

def main():
    """
    Runs the health check system at a configured interval.
    """
    logging.info("Starting health check system...")
    while True:
        check_health()
        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main()
