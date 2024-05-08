#!/bin/bash
input_file="urls.txt"
output_file="output.csv"
if [ ! -f "$input_file" ]; then
    echo "Error: File '$input_file' does not exist."
    exit 1
fi
echo "URLs tested,Login Found,Login URL,Social Media Login Detected" > "$output_file"
timeout_duration="10"  # Timeout after 10 seconds
social_media_patterns='(Log in|Login|Sign in|Continue) with (Google|Facebook|Twitter|LinkedIn|Apple|Microsoft)|Authenticate with (Google|Microsoft)|OAuth'
while IFS= read -r url; do
    echo "Processing $url..."
    response=$(curl -Ls --max-time $timeout_duration -w "%{url_effective}\n" "$url" -o response.html)
    if [ $? -ne 0 ]; then
        echo "Failed to reach $url within the timeout period."
        echo "$url,No,,$social_media_login" >> "$output_file"
        continue
    fi
    final_url=$(echo "$response" | tail -n1)
    initial_domain=$(echo "$url" | awk -F/ '{print $3}')
    final_domain=$(echo "$final_url" | awk -F/ '{print $3}')

    if [[ "$initial_domain" == "$final_domain" ]]; then
        content=$(cat response.html)
        login_detected=$(echo "$content" | grep -oP '<form[^>]*>' | grep -P 'login|log-in|sign-in|signin|authentication|username|password|auth|session|token|credential|forgot-password|reset-password|oauth|register|signup|sign-up|user[ _-]?name|pass[ _-]?word|passwd|account|secure|access|member|log[ _-]?on|signoff|sign-off|logoff|log-off|security|authentic|authorize|access[ _-]?control|authorize|verify|validat|sso|two-factor|2fa|mfa|lockscreen|biometric|fingerprint|face[ _-]?id|otp|one[ _-]?time[ _-]?pass|recover|recovery')
        social_media_login_detected=$(echo "$content" | grep -Eio "$social_media_patterns")

        if [[ -n "$login_detected" || -n "$social_media_login_detected" ]]; then
            echo "Login interface detected at $final_url"
            login_found="Yes"
            social_media_login=$( [[ -n "$social_media_login_detected" ]] && echo "Yes" || echo "No" )
        else
            echo "No login interfaces detected at $final_url"
            login_found="No"
            social_media_login="No"
        fi
    else
        echo "Redirected out of the original domain scope from $url to $final_url"
        login_found="No"
        social_media_login="No"
    fi
    echo "$url,$login_found,$final_url,$social_media_login" >> "$output_file"

    echo "-----------------------------------"
done < "$input_file"

echo "Processing complete."
