#!/usr/bin/env python3
import os, json, time, logging, pandas as pd, boto3
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
DELIVERY_STREAM = os.getenv("FIREHOSE_NAME", "StreamSensorIoT")
REGION = os.getenv("AWS_REGION", "us-east-1")
CSV_PATH = os.getenv("CSV_PATH", "data/IOT-temp.csv")
firehose = boto3.client("firehose", region_name=REGION)
def main():
    if not os.path.exists(CSV_PATH): raise SystemExit(f"CSV file not found: {CSV_PATH}")
    import pandas as pd
    df = pd.read_csv(CSV_PATH); sent = 0
    for _, row in df.iterrows():
        rec = {"id": int(row["id"]), "room_id": int(row["room_id"]), "noted_date": str(row["noted_date"]), "temp": float(row["temp"]), "out_in": str(row["out_in"])}
        firehose.put_record(DeliveryStreamName=DELIVERY_STREAM, Record={"Data": (json.dumps(rec)+"\n").encode("utf-8")}); sent += 1; time.sleep(0.1)
    logging.info("Sent %d IoT records to Firehose %s", sent, DELIVERY_STREAM)
if __name__ == "__main__": main()
