# Use lightweight Python base image
FROM python:3.14-slim

# Set working directory inside container 
WORKDIR /app

# Copy only requirements first (Docker layer caching, this layer only rebuilds if requirements change)
COPY requirements.txt .

# Install Python dependencies without caching pip packages 
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code into container 
COPY app.py .

# Container listens on port 8080 
EXPOSE 8080

# Start the application when container runs
CMD ["python","app.py"]

