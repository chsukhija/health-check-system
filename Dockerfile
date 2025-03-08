# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Copy the current directory contents into the container
COPY . /app

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Create a logs directory
RUN mkdir -p /app/logs

# Run the health check script
CMD ["python", "health_check.py"]
