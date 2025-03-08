import requests
import time
import logging
import json
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError
from config import load_endpoints, CHECK_INTERVAL, RETRY_ATTEMPTS, SLACK_TOKEN, SLACK_CHANNEL

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("logs/health_check.log"),
        logging.StreamHandler()
    ]
)

# Initialize Slack client
slack_client = WebClient(token=SLACK_TOKEN)

def send_alert(message):
    """
    Sends an alert to a Slack channel.
    """
    try:
        slack_client.chat_postMessage(
            channel=SLACK_CHANNEL,
            text=f"🚨 Health Check Alert: {message}"
        )
        logging.error(f"Alert sent to Slack: {message}")
    except SlackApiError as e:
        logging.error(f"Failed to send Slack alert: {e.response['error']}")

def check_endpoint(endpoint):
    """
    Performs a health check for a single endpoint.
    """
    for attempt in range(RETRY_ATTEMPTS):
        try:
            start_time = time.time()
            response = requests.get(endpoint["url"], timeout=5)
            response_time = time.time() - start_time

            # Log response details
            logging.info(f"Health check for {endpoint['name']} ({endpoint['url']}) - Status: {response.status_code}, Response Time: {response_time:.2f}s")

            # Check response time
            if response_time > endpoint["response_time_threshold"]:
                logging.warning(f"Response time exceeded threshold: {response_time:.2f}s > {endpoint['response_time_threshold']}s")
                send_alert(f"{endpoint['name']}: Response time exceeded threshold: {response_time:.2f}s > {endpoint['response_time_threshold']}s")

            # Check HTTP status code
            if response.status_code != endpoint["expected_status"]:
                send_alert(f"{endpoint['name']}: Non-{endpoint['expected_status']} status code: {response.status_code}")

            # Optionally parse response body for health indicators
            if response.status_code == endpoint["expected_status"]:
                if not response.text.strip():  # Check if the response body is empty
                    logging.error(f"{endpoint['name']}: Empty response body")
                    send_alert(f"{endpoint['name']}: Empty response body")
                else:
                    try:
                        health_data = response.json()  # Attempt to parse JSON
                        if health_data.get(endpoint["health_indicator"]) != "ok":
                            send_alert(f"{endpoint['name']}: {endpoint['health_indicator']} issue: {health_data.get(endpoint['health_indicator'])}")
                    except json.JSONDecodeError:
                        logging.error(f"{endpoint['name']}: Invalid JSON response")
                        send_alert(f"{endpoint['name']}: Invalid JSON response")

            break  # Exit retry loop if successful

        except requests.exceptions.RequestException as e:
            logging.error(f"{endpoint['name']}: Attempt {attempt + 1} failed: {e}")
            if attempt == RETRY_ATTEMPTS - 1:
                send_alert(f"{endpoint['name']}: Health check failed after {RETRY_ATTEMPTS} attempts: {e}")
            time.sleep(5)  # Wait before retrying

def main():
    """
    Runs the health check system for all endpoints at a configured interval.
    """
    logging.info("Starting health check system...")
    endpoints = load_endpoints()
    while True:
        for endpoint in endpoints:
            check_endpoint(endpoint)
        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main()
