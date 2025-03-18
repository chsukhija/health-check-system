import aiohttp
import asyncio
import time
import yaml
import logging
from logging.handlers import RotatingFileHandler

# Configure logging
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
handler = RotatingFileHandler("health_check.log", maxBytes=5000000, backupCount=5)
formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
handler.setFormatter(formatter)
logger.addHandler(handler)

# Mock function for sending alerts
def send_alert(message):
    logger.error(f"ALERT: {message}")

def send_alert_pass(message):
    logger.info(f"PASS: {message}")

async def check_endpoint(session, endpoint):
    """
    Check the health of a single endpoint asynchronously.
    """
    url = endpoint["url"]
    expected_response = endpoint.get("expected_response", "UP")

    try:
        start_time = time.time()
        async with session.get(url) as response:
            response_text = await response.text()
            response_time = time.time() - start_time

            if response_text != expected_response and response_text != "":
                send_alert(f"{url}: Unexpected response: {response_text}")
            else:
                send_alert_pass(f"{url}: Passed: {response_text} (Response Time: {response_time:.2f}s)")
    except Exception as e:
        send_alert(f"{url}: Failed with error: {str(e)}")

async def check_all_endpoints(endpoints):
    """
    Check the health of all endpoints in parallel.
    """
    async with aiohttp.ClientSession() as session:
        tasks = [check_endpoint(session, endpoint) for endpoint in endpoints]
        await asyncio.gather(*tasks)

def load_config(config_file):
    """
    Load endpoints from a YAML configuration file.
    """
    with open(config_file, "r") as file:
        return yaml.safe_load(file)

def main():
    """
    Main function to run the health check system.
    """
    config_file = "endpoints.yaml"  # Path to the YAML configuration file
    endpoints = load_config(config_file)

    logger.info("Starting health checks...")
    asyncio.run(check_all_endpoints(endpoints))
    logger.info("Health checks completed.")

if __name__ == "__main__":
    main()
