import os
import requests
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

TELEGRAM_TOKEN   = os.getenv("TELEGRAM_TOKEN")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID")
TELEGRAM_API     = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}"


def send_message(text: str) -> bool:
    try:
        response = requests.post(
            f"{TELEGRAM_API}/sendMessage",
            json={
                "chat_id":    TELEGRAM_CHAT_ID,
                "text":       text,
                "parse_mode": "HTML",
                "disable_web_page_preview": True,
            },
            timeout=10
        )
        if response.status_code == 200:
            print("Telegram alert sent!")
            return True
        print(f"Telegram error: {response.status_code} - {response.text}")
        return False
    except Exception as e:
        print(f"Failed to send alert: {e}")
        return False


def send_rollback_alert(
    service, failed_image, safe_image, reason,
    rollback_status, failed_at, jenkins_url,
    log_lines=None, cloudwatch_url=None, namespace="default"
) -> bool:
    log_section = ""
    if log_lines:
        logs = "\n".join(log_lines[-10:])
        log_section = f"\n<b>Last Log Lines:</b>\n<code>{logs}</code>\n"

    kubectl_cmd = f"kubectl logs deployment/{service} -n {namespace} --tail=50"
    cw_url = cloudwatch_url or "https://console.aws.amazon.com/cloudwatch/home"

    message = (
        "<b>DEPLOYMENT FAILURE - AUTO ROLLBACK</b>\n\n"
        "<b>SERVICE DETAILS</b>\n"
        f"  Service:      <code>{service}</code>\n"
        f"  Failed image: <code>{failed_image}</code>\n"
        f"  Safe image:   <code>{safe_image}</code>\n\n"
        f"<b>TIMESTAMP</b>\n  {failed_at}\n\n"
        f"<b>LOGS</b>\n  {reason}\n"
        f"{log_section}\n"
        f"<b>Rollback Status:</b> {rollback_status}\n\n"
        "<b>Investigate:</b>\n"
        f'  <a href="{jenkins_url}">Jenkins Build Logs</a>\n'
        f'  <a href="{cw_url}">CloudWatch Logs</a>\n'
        f"  <code>{kubectl_cmd}</code>"
    )
    return send_message(message)


def send_safe_build_alert(service, image, minutes, requests, error_rate) -> bool:
    message = (
        "<b>BUILD MARKED SAFE</b>\n\n"
        f"Service: <code>{service}</code>\n"
        f"Image:   <code>{image}</code>\n\n"
        "<b>Passed all thresholds:</b>\n"
        f"  Soak time:  {minutes} min\n"
        f"  Requests:   {requests:,}\n"
        f"  Error rate: {error_rate:.4%}\n\n"
        f"Now the rollback target for <code>{service}</code>."
    )
    return send_message(message)


def send_no_safe_build_alert(service, failed_image) -> bool:
    message = (
        "<b>CRITICAL - MANUAL INTERVENTION REQUIRED</b>\n\n"
        f"<code>{service}</code> failed — no safe build found!\n"
        "Automatic rollback is NOT possible\n\n"
        f"Failed image: <code>{failed_image}</code>\n\n"
        "<b>Action required:</b>\n"
        "  1. Check service logs immediately\n"
        "  2. Manually deploy a known good version\n"
        "  3. Investigate why no safe build exists"
    )
    return send_message(message)