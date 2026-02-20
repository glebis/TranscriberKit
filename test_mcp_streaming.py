#!/usr/bin/env python3
"""Test MCP streaming: progress notifications + resource subscriptions."""

import json
import subprocess
import sys
import threading
import time

SERVER = ".build/release/transcriber-mcp"
msg_id = 0


def next_id():
    global msg_id
    msg_id += 1
    return msg_id


def send(proc, method, params=None, is_notification=False):
    msg = {"jsonrpc": "2.0", "method": method}
    if params:
        msg["params"] = params
    if not is_notification:
        msg["id"] = next_id()
    line = json.dumps(msg) + "\n"
    proc.stdin.write(line)
    proc.stdin.flush()
    return msg.get("id")


def reader_thread(proc):
    """Read stdout and print all messages from server."""
    for line in proc.stdout:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
            if "method" in msg:
                # Notification from server
                method = msg["method"]
                params = msg.get("params", {})
                if method == "notifications/progress":
                    print(f"  [PROGRESS] {params.get('message', '')}")
                elif method == "notifications/resources/updated":
                    print(f"  [RESOURCE UPDATED] {params.get('uri', '')}")
                else:
                    print(f"  [NOTIFICATION] {method}: {params}")
            elif "result" in msg:
                result = msg["result"]
                # Compact print for large results
                text = json.dumps(result, indent=None)
                if len(text) > 200:
                    text = text[:200] + "..."
                print(f"  [RESULT id={msg['id']}] {text}")
            elif "error" in msg:
                print(f"  [ERROR id={msg.get('id')}] {msg['error']}")
        except json.JSONDecodeError:
            print(f"  [RAW] {line}")


def main():
    print(f"Starting MCP server: {SERVER}")
    proc = subprocess.Popen(
        [SERVER],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )

    t = threading.Thread(target=reader_thread, args=(proc,), daemon=True)
    t.start()

    # 1. Initialize
    print("\n--- Initialize ---")
    send(proc, "initialize", {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {"name": "streaming-test", "version": "0.1"},
    })
    time.sleep(0.5)

    send(proc, "notifications/initialized", is_notification=True)
    time.sleep(0.3)

    # 2. Subscribe to live transcript resource
    print("\n--- Subscribe to transcript://live ---")
    send(proc, "resources/subscribe", {"uri": "transcript://live"})
    time.sleep(0.3)

    # 3. Start transcription with progress token
    print("\n--- Start transcription (with progress token) ---")
    send(proc, "tools/call", {
        "name": "start_transcription",
        "arguments": {"locale": "en-US"},
        "_meta": {"progressToken": "test-token-1"},
    })
    time.sleep(0.5)

    # 4. Wait for speech -- notifications should stream in
    print("\n--- Speak into your microphone... (15 seconds) ---")
    print("    Watch for [PROGRESS] and [RESOURCE UPDATED] messages\n")
    time.sleep(15)

    # 5. Stop transcription
    print("\n--- Stop transcription ---")
    send(proc, "tools/call", {
        "name": "stop_transcription",
        "arguments": {},
    })
    time.sleep(1)

    # 6. Read the resource to see final transcript
    print("\n--- Read transcript://live resource ---")
    send(proc, "resources/read", {"uri": "transcript://live"})
    time.sleep(0.5)

    # 7. Cleanup
    print("\n--- Done ---")
    proc.terminate()
    proc.wait(timeout=3)


if __name__ == "__main__":
    main()
