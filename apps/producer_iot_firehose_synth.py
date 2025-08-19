#!/usr/bin/env python3
import os, json, time, random, logging, boto3
from datetime import datetime
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
DELIVERY_STREAM = os.getenv("FIREHOSE_NAME", "StreamSensorIoT")
REGION = os.getenv("AWS_REGION", "us-east-1")
RECORDS = int(os.getenv("RECORDS", "500"))
DELAY_MS = int(os.getenv("DELAY_MS", "50"))
firehose = boto3.client("firehose", region_name=REGION)

def gen_record(i):
    return {
        "id": i,
        "room_id": random.randint(100, 120),
        "noted_date": datetime.utcnow().isoformat(timespec='seconds') + "Z",
        "temp": round(random.uniform(18.0, 32.0), 2),
        "out_in": random.choice(["IN","OUT"]),
    }

def main():
    sent = 0
    for i in range(1, RECORDS+1):
        rec = gen_record(i)
        firehose.put_record(
            DeliveryStreamName=DELIVERY_STREAM,
            Record={"Data": (json.dumps(rec) + "\n").encode("utf-8")}
        )
        sent += 1
        if DELAY_MS > 0:
            time.sleep(DELAY_MS/1000.0)
    logging.info("Sent %d synthetic IoT records to Firehose %s", sent, DELIVERY_STREAM)

if __name__ == "__main__":
    main()
