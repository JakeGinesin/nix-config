# --- CONFIGURATION ---
ip=$(cat /home/synchronous/.agenix/agenix/ip-master-k3s)
SSH_TARGET="synchronous@$ip"
NAMESPACE="ingress-nginx"
POD_LABEL="app=pvc-explorer"
TARGET_DIR="/data"
# ---------------------

# 1. Check for an argument
LOCAL_PATH="$1"
if [ -z "$LOCAL_PATH" ]; then
    echo "Usage: $0 <local-file-or-directory-to-copy>"
    exit 1
fi

if [ ! -e "$LOCAL_PATH" ]; then
    echo "Error: Local path not found: $LOCAL_PATH"
    exit 1
fi

# Define a unique name for the temporary archive
TEMP_ARCHIVE="kube_cp_temp_$(date +%s).tar.gz"

# --- PART 1: Create local archive ---
echo "[Local] Creating temporary archive: $TEMP_ARCHIVE"
tar czf "$TEMP_ARCHIVE" "$LOCAL_PATH"
if [ $? -ne 0 ]; then
    echo "Error: Failed to create local archive."
    rm -f "$TEMP_ARCHIVE" # Clean up on failure
    exit 1
fi

# --- PART 2: Copy archive to remote machine ---
echo "[Local] Copying archive to $SSH_TARGET:~/ "
scp "$TEMP_ARCHIVE" "$SSH_TARGET:~/$TEMP_ARCHIVE"
if [ $? -ne 0 ]; then
    echo "Error: Failed to scp archive to remote machine."
    rm -f "$TEMP_ARCHIVE" # Clean up local
    exit 1
fi

# --- PART 3: Execute remote commands ---
echo "[Local] Connecting via SSH to import archive... You will be prompted for your SUDO password."

# Define the set of commands to run on the remote machine
REMOTE_CMD=$(cat <<EOF
echo "[Remote] Finding pod..."
POD_NAME=\$(sudo kubectl get pods -n "$NAMESPACE" -l "$POD_LABEL" -o jsonpath='{.items[0].metadata.name}')

if [ -z "\$POD_NAME" ]; then
    echo "[Remote] Error: Pod not found with label $POD_LABEL." >&2
    rm -f ~/"$TEMP_ARCHIVE" # Clean up remote archive
    exit 1
fi

echo "[Remote] Found pod: \$POD_NAME"
echo "[Remote] Streaming archive from ~/$TEMP_ARCHIVE into pod..."
cat ~/"$TEMP_ARCHIVE" | sudo kubectl exec -i \$POD_NAME -n "$NAMESPACE" -- tar xzf - -C "$TARGET_DIR"

echo "[Remote] Cleaning up remote archive..."
rm ~/"$TEMP_ARCHIVE"
echo "[Remote] Transfer complete."
EOF
)

# Run the remote commands
ssh -tt "$SSH_TARGET" "$REMOTE_CMD"

# --- PART 4: Local cleanup ---
echo "[Local] Cleaning up local archive: $TEMP_ARCHIVE"
rm "$TEMP_ARCHIVE"

echo "[Local] All done."
