#!/bin/bash
set -e

echo "=== OmniMap Backend Startup ==="

# Wait for database to be ready using Django's check
echo "Waiting for database..."
until python manage.py check --database default 2>/dev/null; do
    echo "Database not ready, waiting..."
    sleep 2
done
echo "Database is ready!"

# Create migrations if needed (for development)
echo "Creating migrations..."
python manage.py makemigrations --noinput || true

# Run migrations
echo "Running migrations..."
python manage.py migrate --noinput

# Collect static files
echo "Collecting static files..."
python manage.py collectstatic --noinput || true

# Create initial data (superuser + required data)
echo "Creating initial data..."
python manage.py create_initial_data || echo "Initial data already exists or command not available"

# Start the server
echo "Starting Django server..."
exec python manage.py runserver 0.0.0.0:8000
