#!/bin/bash
# jenkins-query.sh - Jenkins CI/CD Query Tool
# Query and manage Jenkins builds, jobs, and pipelines.
# Environment: JENKINS_URL, JENKINS_USERNAME, JENKINS_TOKEN
#
# Usage: jenkins-query.sh [--color] <command> [options]
# Global flags:
#   --color                         Enable colored output (off by default)
# Commands:
#   --check                         Test Jenkins connectivity
#   --search <term>                 Search for jobs by name
#   --list <folder> <repo> [branch] List builds in a path
#   --build <folder> <repo> [opts]  Trigger a build
#   --info <fullname>               Get job details
#   --logs <fullname> [opts]        Get build console logs
#   --fetch <url>                   Raw API fetch

set -o errexit
set -o pipefail

# ==============================================================================
# EXIT CODES
# ==============================================================================
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_NETWORK=4
readonly EXIT_AUTH=5
readonly EXIT_NOT_FOUND=6

# ==============================================================================
# CONFIGURATION
# ==============================================================================
: "${JENKINS_URL:?JENKINS_URL environment variable is required}"
: "${JENKINS_USERNAME:?JENKINS_USERNAME environment variable is required}"
: "${JENKINS_TOKEN:?JENKINS_TOKEN environment variable is required}"

# Remove trailing slash from JENKINS_URL if present
JENKINS_URL="${JENKINS_URL%/}"

# ==============================================================================
# COLOR SETUP (off by default, use --color to enable)
# ==============================================================================
RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''

enable_colors() {
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
}

# ==============================================================================
# BLOCKLIST FOR POST REQUESTS
# ==============================================================================
# Load blocklist patterns from external file (one pattern per line, # for comments)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOCKLIST_FILE="${SCRIPT_DIR}/blocklist.txt"

# Load patterns from blocklist file into array
load_blocklist() {
    BLOCKLIST_PATTERNS=()
    if [[ -f "$BLOCKLIST_FILE" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            # Trim whitespace
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [[ -n "$line" ]] && BLOCKLIST_PATTERNS+=("$line")
        done < "$BLOCKLIST_FILE"
    fi
}
load_blocklist

# Check if job path matches any blocklist pattern
# Returns 0 if blocked, 1 if allowed
# Arguments: folder repo [branch]
check_blocklist() {
    local folder="$1"
    local repo="$2"
    local branch="${3:-}"

    local job_path="$folder/$repo"
    [[ -n "$branch" ]] && job_path="$job_path/$branch"

    for pattern in "${BLOCKLIST_PATTERNS[@]}"; do
        if [[ "$job_path" == *"$pattern"* ]]; then
            echo -e "${RED}BLOCKED: Build not allowed for this job${NC}" >&2
            echo "" >&2
            echo "The job \"$job_path\" matches a blocklisted pattern: \"$pattern\"" >&2
            echo "" >&2
            echo "To trigger this build, please run manually in Jenkins UI:" >&2
            echo "  ${JENKINS_URL}/job/${folder// /%20}/job/${repo// /%20}/${branch:+job/${branch// /%20}/}" >&2
            echo "" >&2
            echo "Blocklisted patterns exist to prevent accidental triggering of sensitive jobs." >&2
            return 0
        fi
    done
    return 1
}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Construct Basic auth header
get_auth_header() {
    echo "Authorization: Basic $(echo -n "${JENKINS_USERNAME}:${JENKINS_TOKEN}" | base64)"
}

# URL encode a string (uses jq for reliable encoding)
url_encode() {
    local string="$1"
    printf '%s' "$string" | jq -sRr @uri | tr -d '\n'
}

# URL encode for Jenkins branch names (double-encode to handle slashes)
url_encode_branch() {
    local string="$1"
    url_encode "$(url_encode "$string")"
}

# Core curl wrapper with authentication
do_curl() {
    local url="$1"
    shift
    local full_url

    # If URL doesn't start with http, prepend JENKINS_URL
    if [[ ! "$url" =~ ^https?:// ]]; then
        full_url="${JENKINS_URL}${url}"
    else
        full_url="$url"
    fi

    local http_code
    local response
    local tmpfile
    tmpfile=$(mktemp)

    http_code=$(curl -sSL -k \
        -H "$(get_auth_header)" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -w "%{http_code}" \
        -o "$tmpfile" \
        "$@" \
        "$full_url" 2>/dev/null) || {
        local curl_exit=$?
        rm -f "$tmpfile"
        if [[ $curl_exit -eq 7 ]]; then
            echo -e "${RED}Error: Cannot connect to Jenkins server${NC}" >&2
            echo "Check JENKINS_URL: $JENKINS_URL" >&2
            return $EXIT_NETWORK
        fi
        echo -e "${RED}Error: Network error (curl exit code: $curl_exit)${NC}" >&2
        return $EXIT_NETWORK
    }

    response=$(cat "$tmpfile")
    rm -f "$tmpfile"

    case "$http_code" in
        2*)
            echo "$response"
            return $EXIT_SUCCESS
            ;;
        401)
            echo -e "${RED}Error: Authentication failed (401)${NC}" >&2
            echo "Check JENKINS_USERNAME and JENKINS_TOKEN" >&2
            return $EXIT_AUTH
            ;;
        403)
            echo -e "${RED}Error: Permission denied (403)${NC}" >&2
            echo "User lacks permission for this operation" >&2
            return $EXIT_AUTH
            ;;
        404)
            echo -e "${RED}Error: Not found (404)${NC}" >&2
            echo "Resource does not exist: $full_url" >&2
            return $EXIT_NOT_FOUND
            ;;
        *)
            echo -e "${RED}Error: HTTP $http_code${NC}" >&2
            echo "$response" >&2
            return $EXIT_ERROR
            ;;
    esac
}

# Fetch JSON from Jenkins API (appends /api/json if needed)
fetch_json() {
    local url="$1"
    local query_params="${2:-}"
    shift
    [[ -n "$query_params" ]] && shift

    # Append /api/json if not already present
    if [[ ! "$url" =~ /api/json ]]; then
        url="${url%/}/api/json${query_params}"
    fi

    do_curl "$url" "$@"
}

# Format job status icon
status_icon() {
    local color="$1"
    case "$color" in
        *blue*|*success*) echo -e "${GREEN}✓${NC}" ;;
        *red*|*fail*) echo -e "${RED}✗${NC}" ;;
        *yellow*|*unstable*) echo -e "${YELLOW}!${NC}" ;;
        *grey*|*disabled*|*notbuilt*) echo -e "○" ;;
        *anime*|*building*) echo -e "${CYAN}●${NC}" ;;
        *) echo -e "?" ;;
    esac
}

# ==============================================================================
# COMMANDS
# ==============================================================================

# --check: Test Jenkins connectivity
cmd_check() {
    echo -e "${BOLD}Testing Jenkins connectivity...${NC}"
    echo ""

    local response
    if response=$(do_curl "/" 2>&1); then
        echo -e "${GREEN}✓ Jenkins Server: Healthy${NC}"
        echo -e "  URL: $JENKINS_URL"
        echo -e "  Auth: Working"
        return $EXIT_SUCCESS
    else
        echo "$response"
        return $?
    fi
}

# --search: Search for jobs
cmd_search() {
    local search_term="$1"
    local raw_json="${2:-false}"

    if [[ -z "$search_term" ]]; then
        echo -e "${RED}Error: Search term required${NC}" >&2
        echo "Usage: jenkins-query.sh --search <term>" >&2
        return $EXIT_INVALID_ARGS
    fi

    local response
    response=$(do_curl "/search/suggest?query=$(url_encode "$search_term")") || return $?

    if [[ "$raw_json" == "true" ]]; then
        echo "$response"
        return $EXIT_SUCCESS
    fi

    # Parse and display results
    local count
    count=$(echo "$response" | jq -r '.suggestions | length' 2>/dev/null || echo "0")

    if [[ "$count" == "0" ]]; then
        echo -e "${YELLOW}No jobs found matching '$search_term'${NC}"
        echo ""
        echo "Try:"
        echo "  - Using partial job names"
        echo "  - Checking spelling"
        echo "  - Using broader search terms"
        return $EXIT_SUCCESS
    fi

    echo -e "${BOLD}Found $count jobs matching '$search_term':${NC}"
    echo ""

    echo "$response" | jq -r '.suggestions[] | "\(.name)|\(.url // "")|\(.icon // "")"' 2>/dev/null | while IFS='|' read -r name url icon; do
        local status
        if [[ "$icon" == *"blue"* ]]; then
            status="${GREEN}✓${NC}"
        elif [[ "$icon" == *"red"* ]]; then
            status="${RED}✗${NC}"
        else
            status="○"
        fi
        echo -e "  $status $name"
        if [[ -n "$url" ]]; then
            # Extract fullname from URL for easier use
            local fullname
            fullname=$(echo "$url" | sed -E 's|.*/job/||; s|/job/|/|g; s|/$||')
            echo -e "    ${CYAN}fullname: $fullname${NC}"
        fi
    done
}

# --list: List builds in a folder/repo/branch
cmd_list() {
    local folder="$1"
    local repo="$2"
    local branch="$3"
    local raw_json="${4:-false}"

    if [[ -z "$folder" ]] || [[ -z "$repo" ]]; then
        echo -e "${RED}Error: Folder and repo required${NC}" >&2
        echo "Usage: jenkins-query.sh --list <folder> <repo> [branch]" >&2
        return $EXIT_INVALID_ARGS
    fi

    local url="/job/$(url_encode "$folder")/job/$(url_encode "$repo")"
    if [[ -n "$branch" ]]; then
        url="$url/job/$(url_encode_branch "$branch")"
    fi

    local response
    response=$(fetch_json "$url" "?depth=1") || return $?

    if [[ "$raw_json" == "true" ]]; then
        echo "$response"
        return $EXIT_SUCCESS
    fi

    local path="$folder/$repo"
    [[ -n "$branch" ]] && path="$path/$branch"

    # Check if this is a folder with jobs or a job with builds
    local jobs builds
    jobs=$(echo "$response" | jq -r '.jobs // [] | length' 2>/dev/null)
    builds=$(echo "$response" | jq -r '.builds // [] | length' 2>/dev/null)

    if [[ "$jobs" -gt 0 ]]; then
        echo -e "${BOLD}Jobs in $path:${NC}"
        echo ""
        echo "$response" | jq -r '.jobs[] | "\(.name)|\(.color // "")"' 2>/dev/null | while IFS='|' read -r name color; do
            local icon
            icon=$(status_icon "$color")
            echo -e "  $icon $name"
        done
    elif [[ "$builds" -gt 0 ]]; then
        echo -e "${BOLD}Builds in $path:${NC}"
        echo ""
        echo "$response" | jq -r '.builds[] | "\(.number)|\(.result // "BUILDING")|\(.displayName // "")|\(.description // "")"' 2>/dev/null | head -20 | while IFS='|' read -r number result displayName description; do
            local icon
            icon=$(status_icon "$result")
            # Extract suffix from displayName (e.g., "#31110.micro-kosmos" -> "micro-kosmos")
            local name_suffix=""
            if [[ "$displayName" == *"."* ]]; then
                name_suffix="${displayName#*.}"
            fi
            local output="  $icon #$number - $result"
            [[ -n "$name_suffix" ]] && output="$output ($name_suffix)"
            [[ -n "$description" ]] && output="$output - $description"
            echo -e "$output"
        done
    else
        echo -e "${YELLOW}No jobs or builds found in $path${NC}"
    fi
}

# --build: Trigger a build with parameters
cmd_build() {
    local folder="$1"
    local repo="$2"
    shift 2

    local branch=""
    local raw_json="false"
    declare -a params=()

    # Parse remaining arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--branch)
                branch="$2"
                shift 2
                ;;
            -p|--param)
                params+=("$2")
                shift 2
                ;;
            --json)
                raw_json="true"
                shift
                ;;
            *)
                # If it doesn't start with -, assume it's the branch
                if [[ ! "$1" =~ ^- ]] && [[ -z "$branch" ]]; then
                    branch="$1"
                    shift
                else
                    echo -e "${RED}Error: Unknown option: $1${NC}" >&2
                    return $EXIT_INVALID_ARGS
                fi
                ;;
        esac
    done

    if [[ -z "$folder" ]] || [[ -z "$repo" ]]; then
        echo -e "${RED}Error: Folder and repo required${NC}" >&2
        echo "Usage: jenkins-query.sh --build <folder> <repo> [branch] [-p KEY=VALUE]..." >&2
        return $EXIT_INVALID_ARGS
    fi

    # Check blocklist before triggering build
    if check_blocklist "$folder" "$repo" "$branch"; then
        return $EXIT_ERROR
    fi

    local url="/job/$(url_encode "$folder")/job/$(url_encode "$repo")"
    if [[ -n "$branch" ]]; then
        url="$url/job/$(url_encode_branch "$branch")"
    fi
    url="$url/buildWithParameters"

    # Append parameters as query string (URL encoded)
    if [[ ${#params[@]} -gt 0 ]]; then
        local param_str=""
        for param in "${params[@]}"; do
            local key="${param%%=*}"
            local value="${param#*=}"
            [[ -n "$param_str" ]] && param_str="${param_str}&"
            param_str="${param_str}$(url_encode "$key")=$(url_encode "$value")"
        done
        url="${url}?${param_str}"
    fi

    local response
    response=$(do_curl "$url" -X POST) || return $?

    local path="$folder/$repo"
    [[ -n "$branch" ]] && path="$path/$branch"

    echo -e "${GREEN}✓ Build triggered successfully${NC}"
    echo -e "  Job: $path"
    if [[ ${#params[@]} -gt 0 ]]; then
        echo -e "  Parameters:"
        for param in "${params[@]}"; do
            echo -e "    - $param"
        done
    fi
    echo ""
    echo "Check Jenkins UI for build progress"
}

# --info: Get job information
cmd_info() {
    local fullname="$1"
    local raw_json="${2:-false}"

    if [[ -z "$fullname" ]]; then
        echo -e "${RED}Error: Job fullname required${NC}" >&2
        echo "Usage: jenkins-query.sh --info <fullname>" >&2
        echo "Example: jenkins-query.sh --info 'Kosmos/api-users/main'" >&2
        return $EXIT_INVALID_ARGS
    fi

    # Convert fullname to URL path (replace / with /job/)
    local url_path
    url_path=$(echo "$fullname" | sed 's|/|/job/|g')
    url_path="/job/$url_path"

    local response
    response=$(fetch_json "$url_path?depth=1") || return $?

    if [[ "$raw_json" == "true" ]]; then
        echo "$response"
        return $EXIT_SUCCESS
    fi

    # Parse job info
    local name color buildable
    name=$(echo "$response" | jq -r '.displayName // .name // "Unknown"')
    color=$(echo "$response" | jq -r '.color // "unknown"')
    buildable=$(echo "$response" | jq -r '.buildable // false')

    local icon
    icon=$(status_icon "$color")

    echo -e "${BOLD}Job: $name${NC}"
    echo -e "  Status: $icon $color"
    echo -e "  Buildable: $buildable"
    echo -e "  Path: $fullname"
    echo ""

    # Last build info
    local last_build
    last_build=$(echo "$response" | jq -r '.lastBuild // empty')
    if [[ -n "$last_build" ]]; then
        local build_num build_result
        build_num=$(echo "$last_build" | jq -r '.number // "?"')
        build_result=$(echo "$last_build" | jq -r '.result // "BUILDING"')
        echo -e "${BOLD}Last Build:${NC}"
        echo -e "  Number: #$build_num"
        echo -e "  Result: $build_result"
    fi

    # Health report
    local health
    health=$(echo "$response" | jq -r '.healthReport[0].description // empty')
    if [[ -n "$health" ]]; then
        echo ""
        echo -e "${BOLD}Health:${NC} $health"
    fi

    # Build parameters
    local params
    params=$(echo "$response" | jq -r '.property[]? | select(.parameterDefinitions) | .parameterDefinitions[]? | "\(.name): \(.defaultParameterValue.value // "no default")"' 2>/dev/null)
    if [[ -n "$params" ]]; then
        echo ""
        echo -e "${BOLD}Parameters:${NC}"
        echo "$params" | while read -r param; do
            echo -e "  - $param"
        done
    fi
}

# --logs: Get build console logs (saves to temp file)
cmd_logs() {
    local fullname="$1"
    shift || true

    local build_number="lastBuild"
    local tail_lines=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tail|-n)
                tail_lines="$2"
                shift 2
                ;;
            --build|-b)
                build_number="$2"
                shift 2
                ;;
            *)
                # First positional arg after fullname is build number
                if [[ ! "$1" =~ ^- ]]; then
                    build_number="$1"
                    shift
                else
                    echo "${RED}Error: Unknown option: $1${NC}" >&2
                    return $EXIT_INVALID_ARGS
                fi
                ;;
        esac
    done

    if [[ -z "$fullname" ]]; then
        echo "${RED}Error: Job fullname required${NC}" >&2
        echo "Usage: jenkins-query.sh --logs <fullname> [build_number] [--tail N]" >&2
        return $EXIT_INVALID_ARGS
    fi

    # Convert fullname to URL path
    local url_path
    url_path=$(echo "$fullname" | sed 's|/|/job/|g')
    url_path="/job/$url_path/$build_number/consoleText"

    # Generate temp file with timestamp for uniqueness
    local safe_name timestamp tmpfile
    safe_name=$(echo "$fullname" | tr '/' '-')
    timestamp=$(date +%Y%m%d-%H%M)
    tmpfile="/tmp/jenkins-logs-${safe_name}-${build_number}-${timestamp}.log"

    # Fetch logs to temp file
    do_curl "$url_path" > "$tmpfile" || return $?

    # Output file info
    local line_count file_size
    line_count=$(wc -l < "$tmpfile" | tr -d ' ')
    file_size=$(du -h "$tmpfile" | cut -f1)

    echo "Log saved to: $tmpfile"
    echo "Size: $file_size, Lines: $line_count"

    # If --tail specified, show preview
    if [[ -n "$tail_lines" ]]; then
        echo ""
        echo "--- Last $tail_lines lines ---"
        tail -n "$tail_lines" "$tmpfile"
    fi
}

# --fetch: Raw API fetch
cmd_fetch() {
    local url="$1"
    local as_json="${2:-false}"

    if [[ -z "$url" ]]; then
        echo -e "${RED}Error: URL required${NC}" >&2
        echo "Usage: jenkins-query.sh --fetch <url> [--json]" >&2
        return $EXIT_INVALID_ARGS
    fi

    local response
    if [[ "$as_json" == "true" ]]; then
        response=$(fetch_json "$url") || return $?
    else
        response=$(do_curl "$url") || return $?
    fi

    echo "$response"
}

# ==============================================================================
# HELP
# ==============================================================================

show_help() {
    cat << 'EOF'
jenkins-query.sh - Jenkins CI/CD Query Tool

USAGE:
    jenkins-query.sh [--color] <command> [options]

GLOBAL FLAGS:
    --color
        Enable colored output (off by default).

COMMANDS:
    --check
        Test Jenkins server connectivity and authentication.

    --search <term>
        Search for jobs by name. Returns job names and paths.
        Example: jenkins-query.sh --search api-users

    --list <folder> <repo> [branch]
        List jobs or builds in a folder/repo/branch path.
        Example: jenkins-query.sh --list Kosmos api-users main

    --build <folder> <repo> [branch] [-p KEY=VALUE]...
        Trigger a parameterized build.
        Example: jenkins-query.sh --build Kosmos api-users main -p DEPLOY=true

    --info <fullname>
        Get detailed job information including status, health, and parameters.
        Example: jenkins-query.sh --info "Kosmos/api-users/main"

    --logs <fullname> [build_number] [--tail N]
        Get build console logs. Use 'lastBuild' for most recent (default).
        Example: jenkins-query.sh --logs "Kosmos/api-users/main" --tail 200

    --fetch <url> [--json]
        Raw API fetch. Use --json to auto-append /api/json.
        Example: jenkins-query.sh --fetch /job/Kosmos/api/json

ENVIRONMENT:
    JENKINS_URL       Jenkins server URL (required)
    JENKINS_USERNAME  Jenkins username (required)
    JENKINS_TOKEN     Jenkins API token (required)

EXIT CODES:
    0  Success
    1  General error
    2  Invalid arguments
    4  Network error
    5  Authentication error
    6  Resource not found
EOF
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    # Parse global flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --color)
                enable_colors
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    if [[ $# -eq 0 ]]; then
        show_help
        exit $EXIT_INVALID_ARGS
    fi

    local command="$1"
    shift

    case "$command" in
        --check|check)
            cmd_check "$@"
            ;;
        --search|search|-s)
            cmd_search "$@"
            ;;
        --list|list|-l)
            cmd_list "$@"
            ;;
        --build|build|-b)
            cmd_build "$@"
            ;;
        --info|info|-i)
            cmd_info "$@"
            ;;
        --logs|logs)
            cmd_logs "$@"
            ;;
        --fetch|fetch|-f)
            local url="$1"
            local json_flag="false"
            shift || true
            [[ "$1" == "--json" ]] && json_flag="true"
            cmd_fetch "$url" "$json_flag"
            ;;
        --help|help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Error: Unknown command: $command${NC}" >&2
            echo "Run 'jenkins-query.sh --help' for usage" >&2
            exit $EXIT_INVALID_ARGS
            ;;
    esac
}

main "$@"
