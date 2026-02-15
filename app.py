# app.py
from flask import Flask
import redis
import os

# Initialize Flask application
app = Flask(__name__)

# Connect to Redis
# Uses environment variables for flexibility, defaults to localhost
redis_host = os.environ.get('REDIS_HOST', 'localhost')
redis_port = os.environ.get('REDIS_PORT', 6379)


# Create Redis client
# decode_responses=True returns strings instead of bytes
client = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)

# Route: handles all requests to the root URL "/"
@app.route("/")
def index():
    # INCR command: increments the key "counter" by 1 and returns the new value
    # If the key doesn't exist, Redis creates it and sets it to 1
    counter = client.incr("counter")
    return f"This is the {counter} visitor"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)