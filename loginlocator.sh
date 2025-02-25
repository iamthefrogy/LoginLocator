#!/bin/bash

###############################################################################
# detect_login_compatible.sh
# A more portable Bash script to detect login interfaces using multi-heuristics,
# avoiding GNU-specific "tac" and "grep -P".
#
# Outputs: output.csv with columns:
#   (1) URL tested
#   (2) "Yes"/"No" for login found
#   (3) Final (effective) URL
#   (4) "Yes"/"No" for social-media login
###############################################################################

input_file="urls.txt"
output_file="output.csv"
timeout_duration="10"
score_threshold=5  # If final score >= 5 => login found

# Prepare CSV output
echo "URLs tested,Login Found,Login URL,Social Media Login Detected" > "$output_file"

# Regex for social media login references (in extended regex form, not PCRE)
# We look for patterns like:
#   - "Sign in with Google"
#   - "Continue with Facebook"
#   - "Authenticate with Microsoft"
social_media_patterns='(Log[[:space:]]?[Ii]n|Sign[[:space:]]?[Ii]n|Continue)[[:space:]]?(with|using)[[:space:]]?(Google|Facebook|Twitter|LinkedIn|Apple|Microsoft|GitHub)|Authenticate[[:space:]]?(with|using)[[:space:]]?(Google|Microsoft|GitHub)|OAuth'

###############################################################################
# Function: analyze_content
#   Reads final headers & body, then returns:
#     1) The integer "score"
#     2) "Yes"/"No" for whether social-media login was found
###############################################################################
analyze_content() {
    local headers_file="$1"
    local body_file="$2"

    local score=0
    local social_login="No"

    # Read body into a variable
    local body_content
    body_content=$(cat "$body_file")

    # Read headers into a variable
    local header_content
    header_content=$(cat "$headers_file")

    #-------------------------------------------------------------------------
    # 1) SOCIAL MEDIA LOGIN DETECTION
    #-------------------------------------------------------------------------
    # Use grep -E for extended patterns
    echo "$body_content" | grep -E -i "$social_media_patterns" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        social_login="Yes"
        score=$((score + 3))
    fi

    #-------------------------------------------------------------------------
    # 2) <input type="password">
    #-------------------------------------------------------------------------
    echo "$body_content" | grep -i -E '<input[^>]*type=["'"'"']password["'"'"']' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        score=$((score + 5))
    fi

    #-------------------------------------------------------------------------
    # 3) Form with suspicious attributes (use grep -i -E)
    #-------------------------------------------------------------------------
    # Checking for stuff like action="login.php", id="loginForm", etc.
    echo "$body_content" | grep -i -E '<form[^>]*(action|id|name)[[:space:]]*=[[:space:]]*["'"'"'][^"'"'"']*(login|log-in|signin|sign-in|auth|session|user|passwd|pwd|credential|verify|oauth|token|sso)' \
        >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        score=$((score + 3))
    fi

    #-------------------------------------------------------------------------
    # 4) Textual Indicators: "Forgot Password", "Reset Password", "Sign in", etc.
    #-------------------------------------------------------------------------
    echo "$body_content" | grep -i -E 'Forgot[[:space:]]*Password|Reset[[:space:]]*Password|Sign[[:space:]]*in|Log[[:space:]]*in|Authenticate|Enter[[:space:]]+your[[:space:]]+credentials|Remember[[:space:]]*me|Two[- ]factor|Multi[- ]factor|MFA|OTP|One[- ]time[[:space:]]*pass' \
        >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        score=$((score + 2))
    fi

    #-------------------------------------------------------------------------
    # 5) Hidden fields for tokens/csrf
    #-------------------------------------------------------------------------
    echo "$body_content" | grep -i -E '<input[^>]*type=["'"'"']hidden["'"'"'][^>]*(csrf|token|authenticity|nonce|xsrf)' \
        >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        score=$((score + 2))
    fi

    #-------------------------------------------------------------------------
    # 6) HTTP Status Code: 401/403/407 => +4
    #-------------------------------------------------------------------------
    # We'll find the final status code by looking for lines like:
    # HTTP/1.1 200 OK
    # HTTP/2 401
    # in the headers file. The last such line is presumably the final code.
    local final_code
    final_code=$(echo "$header_content" \
        | grep -E '^HTTP/[0-9]\.?[0-9]?[[:space:]]+[0-9]{3}' \
        | tail -n1 \
        | awk '{print $2}' )
    case "$final_code" in
        401|403|407)
            score=$((score + 4))
            ;;
        *)
            # do nothing
            ;;
    esac

    #-------------------------------------------------------------------------
    # 7) WWW-Authenticate => +4
    #-------------------------------------------------------------------------
    echo "$header_content" | grep -i 'WWW-Authenticate' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        score=$((score + 4))
    fi

    #-------------------------------------------------------------------------
    # 8) Session Cookies => +1
    #-------------------------------------------------------------------------
    # Common session cookie: sessionid, PHPSESSID, JSESSIONID, auth_token, jwt
    echo "$header_content" | grep -i -E 'Set-Cookie:[[:space:]]*(sessionid|PHPSESSID|JSESSIONID|auth_token|jwt)=' \
        >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        score=$((score + 1))
    fi

    # Return results:
    #  - first echo: final score
    #  - second echo: social_login ("Yes"/"No")
    echo "$score"
    echo "$social_login"
}

###############################################################################
# MAIN
###############################################################################
while IFS= read -r url; do
    echo "Processing $url..."

    # We'll store final headers in final_headers.tmp, final body in final_body.tmp
    headers_file="final_headers.tmp"
    body_file="final_body.tmp"
    rm -f "$headers_file" "$body_file"

    # cURL to get final headers & body
    #  -D to write the *final* headers
    #  -o to write the *final* body
    #  -L to follow redirects
    #  --max-time $timeout_duration => sets an overall timeout
    curl -s -S -L --max-time "$timeout_duration" -D "$headers_file" -o "$body_file" "$url"
    if [ $? -ne 0 ]; then
        echo "Failed to reach $url (timeout or other error)."
        echo "$url,No,," >> "$output_file"
        continue
    fi

    # Also determine the final effective URL after redirects
    final_url=$(curl -s -o /dev/null -w "%{url_effective}" -L --max-time "$timeout_duration" "$url")
    if [ -z "$final_url" ]; then
        final_url="$url"
    fi

    # Evaluate domain redirection
    initial_domain=$(echo "$url" | awk -F/ '{print $3}')
    final_domain=$(echo "$final_url" | awk -F/ '{print $3}')

    # Analyze content for login cues
    read score < <(analyze_content "$headers_file" "$body_file")
    read social_login_detected < <(analyze_content "$headers_file" "$body_file" | tail -n1)

    # If domain changed, it might be external SSO => +2
    if [ "$initial_domain" != "$final_domain" ] && [ -n "$final_domain" ]; then
        score=$((score + 2))
    fi

    # Decide if login found
    login_found="No"
    if [ "$score" -ge "$score_threshold" ]; then
        login_found="Yes"
    fi

    # Output to CSV
    echo "$url,$login_found,$final_url,$social_login_detected" >> "$output_file"

    echo "---------------------------------"
done < "$input_file"

rm -rf *.tmp

echo "Processing complete."
