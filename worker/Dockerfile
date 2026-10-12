FROM python:3.14-slim

WORKDIR /worker

# Create a dedicated non-root user
RUN groupadd --system gamevault \
    && useradd --system --gid gamevault gamevault

# Install worker dependencies
RUN pip install --no-cache-dir --upgrade pip setuptools \
    && pip install --no-cache-dir redis

# Copy worker code and give ownership to the app user
COPY --chown=gamevault:gamevault worker.py .

# Run worker as non-root
USER gamevault

CMD ["python", "worker.py"]
