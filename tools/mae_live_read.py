#!/usr/bin/env python3
"""
mae_live_read.py — Live F/T readings from MAE SensuReal sensor.
No ROS2 needed. Just run it.

Usage:
    python3 mae_live_read.py
    python3 mae_live_read.py --ip 192.168.1.11 --rate 50
"""

import argparse
import signal
import sys
import time

import mae_fts_sdk as mae

running = True

def signal_handler(sig, frame):
    global running
    running = False

def main():
    parser = argparse.ArgumentParser(description="MAE SensuReal live reader")
    parser.add_argument("--ip", default="192.168.1.11", help="Sensor IP")
    parser.add_argument("--port", type=int, default=10547, help="Sensor port")
    parser.add_argument("--rate", type=int, default=50, help="Display rate (Hz)")
    parser.add_argument("--tare", action="store_true", help="Tare on startup")
    args = parser.parse_args()

    signal.signal(signal.SIGINT, signal_handler)

    print(f"Connecting to MAE sensor at {args.ip}:{args.port} ...")
    comm = mae.UdpCommunication(ip_address=args.ip, port=args.port, timeout_sec=2)
    comm.connect()
    print("Connected.")

    # Set sampling period to 1kHz
    comm.send_request(mae.FtsCommand.SAMPLING_PERIOD_SET, 1000)
    print("Sampling period: 1000 us (1kHz)")

    if args.tare:
        comm.send_request(mae.FtsCommand.BIAS_SET)
        print("Tared (BIAS_SET).")

    # Start continuous streaming
    comm.send_request(mae.FtsCommand.STREAM_FT_START, 0)
    response_type = mae.FTS_COMMAND_RESPONSE[mae.FtsCommand.STREAM_FT_START]

    # Skip ratio: sensor at 1kHz, display at args.rate Hz
    skip = max(1, 1000 // args.rate)
    count = 0

    print(f"\nDisplay rate: {args.rate} Hz (skip={skip})")
    print("=" * 70)
    print(f"{'Fx (N)':>10} {'Fy (N)':>10} {'Fz (N)':>10} | "
          f"{'Tx (Nm)':>10} {'Ty (Nm)':>10} {'Tz (Nm)':>10}")
    print("=" * 70)

    try:
        while running:
            raw = comm.waits_response_bytes()
            if raw is None:
                continue

            count += 1
            if count % skip != 0:
                continue

            r = response_type(raw)
            # \r overwrites the same line for clean terminal output
            sys.stdout.write(
                f"\r{r.fx:10.3f} {r.fy:10.3f} {r.fz:10.3f} | "
                f"{r.tx:10.4f} {r.ty:10.4f} {r.tz:10.4f}"
            )
            sys.stdout.flush()

    except Exception as e:
        print(f"\nError: {e}")
    finally:
        print("\n\nStopping stream...")
        try:
            comm.send_request(mae.FtsCommand.STREAM_STOP)
        except Exception:
            pass
        comm.disconnect()
        print("Disconnected.")


if __name__ == "__main__":
    main()
