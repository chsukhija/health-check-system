import requests
import time
import logging
import json
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError
from config import load_endpoints, CHECK_INTERVAL, RETRY_ATTEMPTS, SLACK_TOKEN, SLACK_CHANNEL
import os
from pathlib import Path  # Import Path from pathlib

# Create the logs directory if it doesn't exist
logs_dir = Path("logs")
logs_dir.mkdir(exist_ok=True)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(logs_dir / "health_check.log"),  # Use the logs directory
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
            text=f":red_alert: Health Check Alert: {message}"
        )
        logging.error(f"Alert sent to Slack: {message}")
    except SlackApiError as e:
        logging.error(f"Failed to send Slack alert: {e.response['error']}")

def send_alert_pass(message):
    """
    Sends an alert to a Slack channel.
    """
    try:
        slack_client.chat_postMessage(
            channel=SLACK_CHANNEL,
            text=f":green-alert: Health Check Passed: {message}"
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

            # Check plain text response
            if response.status_code == endpoint["expected_status"]:
                response_text = response.text.strip()  # Get the plain text response
                if response_text != endpoint.get("expected_response", "UP"):
                    send_alert(f"{endpoint['url']}: Unexpected response: {response_text}")
                else:
                    send_alert_pass(f"{endpoint['url']}: Passed: {response_text}")
            
            break  # Exit retry loop if successful

        except requests.exceptions.RequestException as e:
            logging.error(f"{endpoint['url']}: Attempt {attempt + 1} failed: {e}")
            if attempt == RETRY_ATTEMPTS - 1:
                send_alert(f"{endpoint['url']}: Health check failed after {RETRY_ATTEMPTS} attempts: {e}")
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
