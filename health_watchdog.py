import time
import threading
import requests
import yaml
from datetime import datetime
from dotenv import load_dotenv
from build_registry import (
    get_build_metrics,
    update_build_metrics,
    get_last_safe_build
)
from rollback_engine import trigger_rollback as execute_rollback

load_dotenv()

def load_config(path: str = "watchdog.yaml") -> dict:
    """Loads watchdog configuration from YAML file."""
    with open(path, "r") as f:
        config = yaml.safe_load(f)
    print(f"Loaded watchdog config: {len(config['services'])} service(s) to monitor")
    return config


def check_health(url: str, timeout: int = 5) -> dict | None:
    """
    Hits the /health endpoint and returns the response.

    Returns:
        dict with health data if successful
        None if the check failed
    """
    try:
        response = requests.get(url, timeout=timeout)

        if response.status_code == 200:
            return response.json(), None
        else:
            print(f"Non-200 response: {response.status_code}")
            return None, f"HTTP {response.status_code} on {url}"

    except requests.exceptions.ConnectionError:
        print(f"Connection refused: {url}")
        return None, f"Connection refused - service is not running at {url}"
    except requests.exceptions.Timeout:
        print(f"Timeout after {timeout}s: {url}")
        return None, f"Timeout after {timeout}s - service is unresponsive"
    except Exception as e:
        print(f"Unexpected error: {e}")
        return None, f"Unexpected error: {e}"

def watch_service(service: dict, watchdog_config: dict):
    """
    Monitors a single service.
    Runs in its own thread so multiple services are watched in parallel.

    Flow:
      1. Wait grace period
      2. Check /health every interval seconds
      3. Track consecutive failures
      4. Trigger rollback after max_failures
      5. Update build registry on success
    """
    name             = service["name"]
    image            = service["image"]
    url              = service["url"]
    grace_period     = watchdog_config["grace_period"]
    interval         = watchdog_config["interval"]
    max_failures     = watchdog_config["max_failures"]

    consecutive_failures = 0
    start_time           = time.time()
    total_requests       = 0
    total_errors         = 0
    baseline_requests = None

    print(f"\nWatching [{name}] | image: {image}")
    print(f"  URL: {url}")
    print(f"  Grace period: {grace_period}s → first check at T+{grace_period}s")

    print(f"\n[{name}] Waiting {grace_period}s grace period...")
    time.sleep(grace_period)
    print(f"[{name}] Grace period complete — starting health checks")

    while True:
        elapsed_seconds  = time.time() - start_time
        elapsed_minutes  = int(elapsed_seconds / 60)
        timestamp        = datetime.now().strftime("%H:%M:%S")

        print(f"\n[{name}] T+{int(elapsed_seconds)}s | Checking {url}")

        health_data, failure_reason = check_health(url)

        if health_data:
            consecutive_failures = 0

            raw_requests = health_data.get("total_requests", 0)
            if baseline_requests is None:
                baseline_requests = raw_requests
                existing = get_build_metrics(name, image)
                if existing:
                    requests_offset = existing.get('requests', 0)
                    runtime_offset = existing.get('running_time', 0)
                continue
            if total_requests == 0 and elapsed_minutes == 0:
                time.sleep(interval)
                continue

            total_requests = max(0, raw_requests - baseline_requests) + requests_offset
            elapsed_minutes = int(elapsed_seconds / 60) + runtime_offset
            error_rate     = health_data.get("error_rate", 0.0)
            total_errors   = int(total_requests * error_rate)

            print(f"[{timestamp}] {name} is healthy | "
                  f"{elapsed_minutes}min | "
                  f"{total_requests:,} reqs | "
                  f"{error_rate:.4%} err")

            try:
                update_build_metrics(
                    service      = name,
                    image        = image,
                    running_time = elapsed_minutes,
                    requests     = total_requests,
                    error_rate   = error_rate,
                )
            except Exception as e:
                print(f"[{name}] DB update failed: {e}")

        else:
            consecutive_failures += 1
            total_errors         += 1

            print(f"[{timestamp}] {name} FAILED "
                  f"({consecutive_failures}/{max_failures} consecutive failures)")

            if consecutive_failures >= max_failures:
                print(f"\n[{name}] ROLLBACK TRIGGERED after {max_failures} failures!")
                trigger_rollback(
                    service          = name,
                    failed_image     = image,
                    elapsed_seconds  = elapsed_seconds,
                    total_requests   = total_requests,
                    total_errors     = total_errors,
                    failure_reason   = failure_reason
                )
                return

        time.sleep(interval)

def trigger_rollback(
    service:         str,
    failed_image:    str,
    elapsed_seconds: float,
    total_requests:  int,
    total_errors:    int,
    failure_reason:  str,
):
    """
    Called when a service fails max_failures consecutive health checks.

    1. Looks up last safe build from registry
    2. Prints rollback target (Rollback Engine will execute it)
    3. Captures failure context for Telegram alert
    """
    print(f"\n{'='*60}")
    print(f"ROLLBACK INITIATED")
    print(f"{'='*60}")
    print(f"  Service:        {service}")
    print(f"  Failed image:   {failed_image}")
    print(f"  Time alive:     {int(elapsed_seconds)}s")
    print(f"  Total requests: {total_requests:,}")
    print(f"  Total errors:   {total_errors:,}")

    safe_build = get_last_safe_build(service, exclude_image=failed_image)

    if safe_build:
        print(f"\nRollback target found:")
        print(f"   Image:      {safe_build['image']}")
        print(f"   Recorded:   {safe_build['created_at']}")
        print(f"   Error rate: {float(safe_build['error_rate']):.4%}")
        print(f"   Requests:   {safe_build['requests']:,}")

        failure_context = {
            "service":       service,
            "failed_image":  failed_image,
            "safe_image":    safe_build["image"],
            "elapsed":       int(elapsed_seconds),
            "total_requests": total_requests,
            "total_errors":  total_errors,
            "timestamp":     datetime.now().isoformat(),
        }

        print(f"\nFailure context captured:")
        for key, value in failure_context.items():
            print(f"   {key}: {value}")

        print(f"\nNext step: Rollback Engine will deploy {safe_build['image']}")
        execute_rollback(service,failed_image, failure_reason)
        return failure_context

    else:
        print(f"\nWARNING: No safe build found for {service}!")
        print(f"   Cannot rollback — no verified stable version exists.")
        print(f"   Manual intervention required!")
        return None


def main():
    print("\nHealth Watchdog Starting\n" + "─" * 60)

    config           = load_config("watchdog.yaml")
    watchdog_config  = config["watchdog"]
    services         = config["services"]

    print(f"\nWatchdog settings:")
    print(f"   Grace period: {watchdog_config['grace_period']}s")
    print(f"   Interval:     {watchdog_config['interval']}s")
    print(f"   Max failures: {watchdog_config['max_failures']}")
    print(f"   Time to rollback: "
          f"{watchdog_config['grace_period'] + watchdog_config['max_failures'] * watchdog_config['interval']}s")

    threads = []
    for service in services:
        thread = threading.Thread(
            target=watch_service,
            args=(service, watchdog_config),
            daemon=True,
            name=f"watchdog-{service['name']}"
        )
        threads.append(thread)
        thread.start()
        print(f"\nStarted watchdog thread for [{service['name']}]")

    try:
        while any(t.is_alive() for t in threads):
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n\nWatchdog stopped by user")


if __name__ == "__main__":
    main()