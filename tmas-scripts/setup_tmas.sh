#!/bin/bash
# Copyright (C) 2025 Trend Micro Inc. All rights reserved.

print_help() {
	echo "Usage: $0 [--install / --metadata-lookup] [--install-dir <directory>] --version <version> [--debug] [--help / -h]"
	echo "Options:"
	echo "  --metadata-lookup      Prints the validated TMAS version, or the latest version if 'latest' is specified"
	echo "  --install              Enable the download and installation of TMAS"
	echo "  --version <version>    Specify the TMAS version, for example, latest, 2, or 2.48.0 (required with --install and --metadata-lookup)"
	echo "  --install-dir <dir>    Specify the installation directory (required with --install)"
	echo "  --debug                Enable debug mode"
	echo "  --help, -h             Show this help message"
}

# Exit immediately if a command exits with a non-zero status
set -e

# Add a flag to enable debug mode
DEBUG=false

# Add a flag to enable the download and installation of TMAS
ENABLE_INSTALL=false

# Add a flag to specify the installation directory
INSTALL_DIR=""

# Add a flag to specify the TMAS version [latest, 2, 2.0.0, etc.]
TMAS_VERSION=""

# Add a flag to enable metadata lookup, which is used to fetch the latest version of TMAS
METADATA_LOOKUP=false

# Global variables
TMAS_LATEST_VERSION=""
TMAS_METADATA_JSON=""
DOWNLOAD_URL=""
TMAS_PATH_TO_CLI=""
MAPPED_ARCH=""
MAPPED_OS=""
CURL_FLAGS=(--fail --connect-timeout 5 --max-time 10 --retry 5 --retry-delay 0 --retry-max-time 40)

main() {
	# Parse input arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--debug)
			DEBUG=true
			shift
			;;
		--install)
			ENABLE_INSTALL=true
			shift
			;;
		--metadata-lookup)
			METADATA_LOOKUP=true
			shift
			;;
		--install-dir)
			if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
				INSTALL_DIR="$2"
				shift 2
			else
				log_error "--install-dir requires a non-empty value."
				exit 1
			fi
			;;
		--version)
			if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
				TMAS_VERSION="$2"
				shift 2
			else
				log_error "--version requires a value."
				exit 1
			fi
			;;
		--help | -h)
			print_help
			exit 0
			;;
		*)
			log_error "Unknown option '$1'."
			print_help
			exit 1
			;;
		esac
	done

	# Check if curl is installed
	if ! command -v curl &>/dev/null; then
		log_error "curl is not installed."
		exit 1
	else
		if ! $DEBUG; then
			CURL_FLAGS+=(-s) # Add silent mode to curl flags
		fi
	fi

	# Check if jq is installed
	if ! command -v jq &>/dev/null; then
		log_error "jq is not installed."
		exit 1
	fi

	# Ensure that either --install or --metadata-lookup is specified
	if ! $ENABLE_INSTALL && ! $METADATA_LOOKUP; then
		log_error "Please specify either --install or --metadata-lookup."
		print_help
		exit 1
	fi

	# Ensure that --install-dir is specified if --install is used
	if $ENABLE_INSTALL && [ -z "$INSTALL_DIR" ]; then
		log_error "--install-dir must be specified when using --install."
		print_help
		exit 1
	fi

	# Ensure a version was specified [latest, 2.0.0, etc.]
	if [ -z "$TMAS_VERSION" ]; then
		log_error "TMAS version was not specified, please use the --version flag to specify it."
		print_help
		exit 1
	# If the version is 'latest', fetch the latest version from the metadata file
	elif [ "$TMAS_VERSION" = "latest" ]; then
		fetchTMASMetadata
		TMAS_VERSION="$TMAS_LATEST_VERSION" # global variable
	# If the version is a major version, fetch the latest version for that major version
	elif [[ "$TMAS_VERSION" =~ ^[0-9]+$ ]]; then
		fetchTMASMetadata
		if ! resolveMajorVersion "$TMAS_VERSION"; then
			exit 1
		fi
		log_verbose "Resolved version: $TMAS_VERSION"
	# Ensure the version is in the format of X.X.X (e.g., 2.48.0), and is supported
	elif ! isValidVersion "$TMAS_VERSION"; then
		exit 1
	fi

	if $METADATA_LOOKUP; then
		echo "$TMAS_VERSION" # print the validated and transformed version so user can capture it
		exit 0
	fi

	if $ENABLE_INSTALL; then
		setOSandArch
		getDownloadObject "$TMAS_VERSION" "$MAPPED_OS" "$MAPPED_ARCH"
		downloadFromUrl "$DOWNLOAD_URL" "$MAPPED_OS"

		# Move the TMAS binary to the specified installation directory
		installTMAS "$TMAS_PATH_TO_CLI" "$INSTALL_DIR"
	fi
}

# Function to log messages in debug mode, send the message to stderr so stdout is not polluted
log_verbose() {
	if $DEBUG; then
		echo "[DEBUG] $1" >&2
	fi
}

# Function to log error messages in stderr
log_error() {
	echo "[ERROR] $1" >&2
}

setOSandArch() {
	local platform
	local arch
	platform=$(uname -s)
	arch=$(uname -m)
	log_verbose "Mapping architecture: ${arch}"
	MAPPED_ARCH=$(mapArch "$arch") # global variable
	log_verbose "Mapping OS: ${platform}"
	MAPPED_OS=$(mapOS "$platform") # global variable
}

# Map architecture to the desired format
# For reference, https://github.com/systemd/systemd/blob/db58f6a9338d30935aa219bec9a8a853cc807756/src/basic/architecture.c
# and https://en.wikipedia.org/wiki/Uname
mapArch() {
	case "$1" in
	arm64) echo "arm64" ;; # redundant but good for docs
	aarch64) echo "arm64" ;;
	arm*) echo "arm64" ;;
	x86_64) echo "x86_64" ;; # redundant but good for docs
	i386 | i486 | i586 | i686) echo "i386" ;;
	*) echo "$1" ;;
	esac
}

# Map OS to the desired format
mapOS() {
	case "$1" in
	CYGWIN* | MINGW* | MSYS* | Windows*) echo "Windows" ;;
	*) echo "$1" ;;
	esac
}

# Function to generate the download URL
getDownloadObject() {
	local tmasVersion="$1"
	local mappedOs="$2"
	local mappedArch="$3"
	local filename
	local extension
	local url

	if [ -z "$tmasVersion" ]; then
		log_error "Version is empty. Exiting."
		exit 1
	elif [ -z "$mappedOs" ]; then
		log_error "Mapped OS is empty. Exiting."
		exit 1
	elif [ -z "$mappedArch" ]; then
		log_error "Mapped architecture is empty. Exiting."
		exit 1
	fi

	filename="tmas-cli_${mappedOs}_${mappedArch}"
	extension=$([[ "$mappedOs" == "Linux" ]] && echo "tar.gz" || echo "zip")
	url="https://cli.artifactscan.cloudone.trendmicro.com/tmas-cli/${tmasVersion}/${filename}.${extension}"

	DOWNLOAD_URL="$url" # global variable
	log_verbose "Generated download URL: $DOWNLOAD_URL"
}

downloadFromUrl() {
	local url="$1"
	local mapOS="$2"
	local downloadFilePrefix
	local tmpDir="${TMPDIR:-$(pwd)}"
	local originalDir
	originalDir=$(pwd)

	downloadFilePrefix="tmas-compressed"

	if [ -z "$url" ]; then
		log_error "URL is empty. Exiting."
		exit 1
	elif [ -z "$mapOS" ]; then
		log_error "mapOS is empty. Exiting."
		exit 1
	elif [ "$mapOS" = "Linux" ]; then
		log_verbose "Downloading and extracting TMAS CLI for Linux"
		downloadFileName="$tmpDir/$downloadFilePrefix.tar.gz"
		if ! curl "${CURL_FLAGS[@]}" -f "$url" -o "$downloadFileName"; then
			log_error "Failed to download the file. Please check the URL, the TMAS version, or your network connection. Exiting."
			rm -rf "$downloadFileName"
			exit 1
		fi
		cd "$tmpDir"
		if ! tar -xz -f "$downloadFileName" tmas; then
			log_error "Failed to extract the file. Exiting."
			rm -rf "$downloadFileName"
			cd "$originalDir"
			exit 1
		fi
		rm -rf "$downloadFileName"
		cd "$originalDir"
	else
		log_verbose "Downloading and extracting TMAS CLI for non-Linux platform"
		downloadFileName="$tmpDir/$downloadFilePrefix.zip"
		if ! curl "${CURL_FLAGS[@]}" -f "$url" -o "$downloadFileName"; then
			log_error "Failed to download the file. Please check the URL, the TMAS version, or your network connection. Exiting."
			rm -rf "$downloadFileName"
			exit 1
		fi
		cd "$tmpDir"
		if ! unzip -p "$downloadFileName" tmas >"$tmpDir/tmas"; then
			log_error "Failed to unzip the file. Exiting."
			rm -rf "$downloadFileName"
			cd "$originalDir"
			exit 1
		fi
		chmod +x "$tmpDir/tmas"
		rm -rf "$downloadFileName"
		cd "$originalDir"
	fi

	TMAS_PATH_TO_CLI="$tmpDir/tmas" # global variable
	log_verbose "Path to Downloaded TMAS CLI: $TMAS_PATH_TO_CLI"

}

# Function to install into the specified directory
installTMAS() {
	local tmasPath="$1"
	# Set installation directory to the provided value or default to the current directory
	local installDir="${2:-$(pwd)}"

	log_verbose "Installing TMAS CLI to $installDir"

	if [ ! -d "$installDir" ]; then
		log_verbose "Installation directory does not exist. Creating: $installDir"
		mkdir -p "$installDir"
	fi

	# Check if source and destination are different before moving
	if [ "$tmasPath" != "$installDir/tmas" ]; then
		mv "$tmasPath" "$installDir/tmas"
	else
		log_verbose "TMAS is already in the target location, skipping move"
	fi

	log_verbose "TMAS installed to $installDir/tmas"
	TMAS_PATH_TO_CLI="$installDir/tmas" # Update global variable
}

fetchTMASMetadata() {
	local latest_version_string

	log_verbose "Fetching TMAS metadata"
	if ! TMAS_METADATA_JSON=$(curl "${CURL_FLAGS[@]}" "https://cli.artifactscan.cloudone.trendmicro.com/tmas-cli/metadata.json"); then
		log_error "Failed to fetch TMAS metadata."
		exit 1
	fi
	if [ -z "$TMAS_METADATA_JSON" ]; then
		log_error "Failed to fetch TMAS metadata."
		exit 1
	fi

	# Extract latest version
	if ! latest_version_string=$(echo "$TMAS_METADATA_JSON" | jq -r '.latestVersion'); then
		log_error "Failed to parse latest TMAS version from metadata."
		exit 1
	fi
	if [ -z "$latest_version_string" ] || [ "$latest_version_string" = "null" ]; then
		log_error "Failed to parse latest TMAS version from metadata."
		exit 1
	fi
	TMAS_LATEST_VERSION="${latest_version_string:1}" # global variable
	log_verbose "Latest TMAS version: $TMAS_LATEST_VERSION"
}

# Function to resolve a major version to the latest version for that major version
resolveMajorVersion() {
	local major_version="$1"
	local field_name="latestV${major_version}"
	local version_string
	
	log_verbose "Looking for latest version of major version $major_version"
	
	# Check if major version is unsupported by this tool (versions less than 2)
	if [ "$major_version" -lt 2 ]; then
		log_error "Major version is unsupported."
		return 1
	fi
	
	# Check if the field exists in the metadata
	if ! version_string=$(echo "$TMAS_METADATA_JSON" | jq -r ".$field_name"); then
		log_error "Failed to query metadata for major version $major_version."
		return 1
	fi
	
	if [ -z "$version_string" ] || [ "$version_string" = "null" ]; then
		log_error "Major version does not exist."
		return 1
	fi
	
	# Remove the 'v' prefix from the version string
	local resolved_version="${version_string:1}"
	
	# Validate the resolved version
	if ! isValidVersion "$resolved_version"; then
		log_error "Major version $major_version is unsupported by this tool."
		return 1
	fi
	
	# Set the global TMAS_VERSION to the resolved version
	TMAS_VERSION="$resolved_version"
	log_verbose "Resolved major version $major_version to: $resolved_version"
	
	return 0
}

# Function to validate the version format
isValidVersion() {
	local version="$1"
	# Check if the version matches the format X.X.X (e.g., 2.48.0)
	if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		# Extract the major version, and ensure that the specified version is constrained to the same major version of TMAS that this tool supports
		local major_version="${version%%.*}"
		if [ "$major_version" -eq 2 ]; then
			# Extract the minor version, make sure it is permanently available for download. All versions 2.48.0 and later are permanently available for download.
			local minor_version="${version#*.}" # remove the major version (eg. 2.X.X becomes X.X)
			minor_version="${minor_version%%.*}"
			if [ "$minor_version" -lt 48 ]; then
				log_error "This tool only supports TMAS versions 2.48.0 and later."
				return 1 # this version is not available for download
			fi
			return 0 # valid format
		fi
		log_error "This tool only supports TMAS versions 2.X.X"
		return 1 # this version is incompatible with this tool
	fi
	log_error "Version must be in the format X.X.X (e.g., 2.48.0), 'latest', or '2'."
	return 1 # invalid format
}

main "$@"