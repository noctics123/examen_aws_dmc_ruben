#!/usr/bin/env python3
import os, json, time, uuid, logging, requests, boto3
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
STREAM_NAME = os.getenv("STREAM_NAME", "streamvuelos")
REGION = os.getenv("AWS_REGION", "us-east-1")
API_KEY = os.getenv("AVIATIONSTACK_KEY", "")
API_URL = os.getenv("AVIATIONSTACK_URL", "http://api.aviationstack.com/v1/flights")
PAGE_LIMIT = int(os.getenv("PAGE_LIMIT", "1"))
kinesis = boto3.client("kinesis", region_name=REGION)
def send_record(rec: dict):
    kinesis.put_record(StreamName=STREAM_NAME, Data=json.dumps(rec).encode("utf-8"), PartitionKey=str(uuid.uuid4()))
def main():
    if not API_KEY: raise SystemExit("Set AVIATIONSTACK_KEY env var.")
    params, sent = {"access_key": API_KEY}, 0
    for page in range(1, PAGE_LIMIT+1):
        params["offset"] = (page-1)*100
        try:
            resp = requests.get(API_URL, params=params, timeout=15); resp.raise_for_status()
            data = resp.json()
        except Exception as e:
            logging.error("API request failed: %s", e); break
        for f in data.get("data", []):
            record = {
                "fecha_vuelo": f.get("flight_date"),
                "estado_vuelo": f.get("flight_status"),
                "aerolinea": (f.get("airline") or {}).get("name"),
                "aeropuerto_salida": (f.get("departure") or {}).get("airport"),
                "hora_vuelo_salida": (f.get("departure") or {}).get("scheduled"),
                "aeropuerto_llegada": (f.get("arrival") or {}).get("airport"),
                "hora_vuelo_llegada": (f.get("arrival") or {}).get("scheduled"),
                "flight_number": (f.get("flight") or {}).get("number"),
            }
            send_record(record); sent += 1; time.sleep(0.2)
        if not data.get("pagination") or not data["pagination"].get("total"): break
    logging.info("Sent %d records to %s", sent, STREAM_NAME)
if __name__ == "__main__": main()
