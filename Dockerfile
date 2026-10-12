FROM python:3.14-slim

WORKDIR /app

# Create a dedicated non-root user
RUN groupadd --system gamevault \
    && useradd --system --gid gamevault gamevault

# Install Python dependencies
COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip setuptools \
    && pip install --no-cache-dir -r requirements.txt

# Copy application files and give ownership to the app user
COPY --chown=gamevault:gamevault . .

# Run the application as non-root
USER gamevault

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

