#!/bin/bash

APK_PATH="$1"
PACKAGE_NAME="$2"
DEVICES="devices.txt"
FAILED_DEVICES=()

if [ -z "$APK_PATH" ] || [ -z "$PACKAGE_NAME" ]; then
  echo "Error: Missing arguments."
  echo "Usage: ./deploy.sh <apk_path> <package_name>"
  exit 1
fi

if [ ! -f "$DEVICE_FILE" ]; then
  echo "$DEVICE_FILE not found"
  exit 1
fi

echo "Starting deployment"

# iterate through devices
while IFS= read -r ip || [ -n "$ip" ]; do
  # Ignore comments, empty lines, and rem whitespace
  [[ "$ip" =~ ^#.*$ ]] && continue
  [[ -z "$ip" ]] && continue
  ip=$(echo "$ip" | xargs)

  echo "---------------------------------------------------"
  echo "Trying to connect to $ip"

  adb disconnect > /dev/null 2>&1
  
  # Connect
  adb connect "$ip"
  
  # Check if connected successfully
  if adb -s "$ip" get-state 2>/dev/null | grep -q "device"; then
    echo "Connected to $ip"
    
    echo "Installing APK..."
    if adb -s "$ip" install -d "$APK_PATH"; then
      echo "Install success"

      echo "Notifying Device"
      adb -s "$ip" shell input keyevent KEYCODE_WAKEUP
      adb shell cmd notification post 'MyTag' 'Hello World!'

      echo "Launching App"
      adb -s "$ip" shell am start -n "$PACKAGE_NAME/.MainActivity" > /dev/null 2>&1

    else
      echo "Install failed for $ip"
      FAILED_DEVICES+=("$ip (Install Failure)")
    fi
    
    adb disconnect > /dev/null
    
  else
    echo "Could not reach $ip. Make sure it is connected to SymAI and powered on."
    FAILED_DEVICES+=("$ip (Unreachable)")
  fi

done < "$DEVICE_FILE"

# Results
echo "---------------------------------------------------"
echo "Deployment loop finished"

if [ ${#FAILED_DEVICES[@]} -ne 0 ]; then
  echo "::warning title=Did not deploy to all devices::Failed to deploy to ${#FAILED_DEVICES[@]} devices: ${FAILED_DEVICES[*]}"
else
  echo "Deployed to all devices"
fi