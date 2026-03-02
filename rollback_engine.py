"""
Rollback Engine — Self-Healing CI/CD Pipeline
=============================================
Triggers the Jenkins rollback job remotely via Jenkins API.
Called by the Health Watchdog when a service fails health checks.
"""

import requests
import os
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

JENKINS_URL      = os.getenv("JENKINS_URL","http://54.224.78.221:8080")
JENKINS_USER     = os.getenv("JENKINS_USER","admin")
JENKINS_TOKEN    = os.getenv("JENKINS_TOKEN","")
JENKINS_JOB_NAME = os.getenv("JENKINS_JOB","rollback-engine")


def get_crumb() -> dict | None:
    """
    Jenkins requires a CSRF crumb for all POST requests.
    Think of it as a one-time token that proves the request is legitimate.
    """
    try:
        response = requests.get(
            f"{JENKINS_URL}/crumbIssuer/api/json",
            auth=(JENKINS_USER, JENKINS_TOKEN),
            timeout=10
        )
        if response.status_code == 200:
            data = response.json()
            return {data["crumbRequestField"]: data["crumb"]}
        return None
    except Exception as e:
        print(f"Could not get Jenkins crumb: {e}")
        return None


def trigger_rollback(
    service:        str,
    failed_image:   str,
    failure_reason: str = "Health check failed 5 consecutive times",
) -> bool:
    """
    Triggers the Jenkins rollback job via REST API.

    Jenkins API endpoint:
        POST /job/<job-name>/buildWithParameters

    Returns True if job was triggered successfully, False otherwise.
    """
    print(f"\nTriggering Jenkins rollback job...")
    print(f"   Service:  {service}")
    print(f"   Failed:   {failed_image}")
    print(f"   Reason:   {failure_reason}")

    crumb = get_crumb()
    headers = crumb or {}

    params = {
        "SERVICE_NAME":   service,
        "FAILED_IMAGE":   failed_image,
        "FAILURE_REASON": failure_reason,
        "FAILED_AT":      datetime.now().isoformat(),
    }

    try:
        response = requests.post(
            f"{JENKINS_URL}/job/{JENKINS_JOB_NAME}/buildWithParameters",
            auth=(JENKINS_USER, JENKINS_TOKEN),
            headers=headers,
            params=params,
            timeout=10
        )

        if response.status_code in [200, 201]:
            print(f"Jenkins job triggered successfully!")
            print(f"   Job URL: {JENKINS_URL}/job/{JENKINS_JOB_NAME}")
            return True
        else:
            print(f"Failed to trigger Jenkins job: {response.status_code}")
            print(f"   Response: {response.text}")
            return False

    except Exception as e:
        print(f"Error triggering Jenkins job: {e}")
        return False


if __name__ == "__main__":
    print("\nRollback Engine — Quick Test\n" + "─" * 40)

    success = trigger_rollback(
        service        = "payment-api",
        failed_image   = "payment-api:v101",
        failure_reason = "Health check failed 5 consecutive times",
    )

    if success:
        print("\nRollback job triggered — check Jenkins dashboard!")
    else:
        print("\nFailed to trigger rollback — check Jenkins credentials")