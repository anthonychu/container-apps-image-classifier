from socket import timeout
from time import sleep
from azure.identity import DefaultAzureCredential
from azure.storage.queue import (
        QueueServiceClient,
        BinaryBase64EncodePolicy,
        BinaryBase64DecodePolicy
)
import os
import requests
from predict import predict_image_from_url
import signal
import uuid

worker_id = str(uuid.uuid4())
keep_running = True

def handler_stop_signals(signum, frame):
    global keep_running
    keep_running = False

signal.signal(signal.SIGINT, handler_stop_signals)
signal.signal(signal.SIGTERM, handler_stop_signals)

default_credential = DefaultAzureCredential()
client = QueueServiceClient(os.environ['AZURE_QUEUE_SERVICE_URL'], credential=default_credential)
queue_client = client.get_queue_client("images", 
                    message_encode_policy = BinaryBase64EncodePolicy(),
                    message_decode_policy = BinaryBase64DecodePolicy())

while keep_running:
    try:
        print("Checking for a message...")
        message = queue_client.receive_message(timeout=30)
        if message:
            image_url = message.content.decode("utf-8") 
            print(image_url)
            results = predict_image_from_url(image_url)
            print(results)
            process_result = {
                'imageUrl': image_url,
                'prediction': results['predictedTagName'],
                'workerId': worker_id
            }
            requests.post(os.environ['FRONTEND_RESULT_URL'], json=process_result)
            queue_client.delete_message(message)
        else:
            sleep(5)
    except Exception as e:
        print(e)

if (not keep_running):
    print("Shutting down...")