import httpx

def check():
    try:
        res = httpx.get("http://localhost:8000/api/v1/health")
        print("Health Check Response:", res.json())
    except Exception as e:
        print("Health Check Failed:", e)

if __name__ == "__main__":
    check()
