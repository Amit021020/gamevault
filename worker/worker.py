import redis
import os
redis_client = redis.Redis(
    host=os.getenv('REDIS_HOST', 'localhost'),
    port=os.getenv('REDIS_PORT', 6379),
    decode_responses=True,
    socket_timeout=None
)

QUEUE_NAME = "gamevault_queue"

print("GameVault worker started..." ,flush=True)
print(f"Waiting for jobs from '{QUEUE_NAME}'...", flush=True)

while True:
    job = redis_client.brpop(QUEUE_NAME, timeout=0)  

    if job:
        queue_name, job_data = job

        print(f"Processing job: {job_data}",flush=True)

