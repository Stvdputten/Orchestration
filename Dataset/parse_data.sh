#!/bin/bash

# Define the source directories and the destination directory
dest_dir="data_test/exp-7-8-9"
src_dirs=(
#     $(ls ./Hashi/*-05-24/*/*/*/nomad-* 2>/dev/null)
#     $(ls ./Hashi/30-07-24/*/*/*/nomad-* 2>/dev/null)
#     $(ls ./Swarm/*-07-24/*/*/*/swarm-*  2>/dev/null)
    $(ls ./Swarm/*-07-24/[789]/*/*/swarm-* 2>/dev/null)
#     $(ls ./Kubernetes/30-07-24/*/*/*/k8s-* 2>/dev/null)
#     $(ls ./Kubernetes/30-07-24/14/*/*/k8s-* 2>/dev/null)
)

# Create the destination directory if it does not exist
mkdir -p "$dest_dir"

# Function to copy and rename duplicates
copy_and_rename() {
	local src_file="$1"
	local base_name
	base_name=$(basename "$src_file")
	local dest_file="$dest_dir/$base_name"
	local counter=1

	# Loop until a unique filename is found
	while [[ -e "$dest_file" ]]; do
		dest_file="$dest_dir/${base_name%.*}_$counter.${base_name##*.}"
		((counter++))
	done

	# Copy the file to the destination directory with the unique name
	cp "$src_file" "$dest_file"
}

# Iterate over each source directory
for dir in "${src_dirs[@]}"; do
	# Find all files in the current directory
	find "$dir" -type f | while read -r file; do
		copy_and_rename "$file"
	done
done

echo "Files copied successfully."

# ./nomad-sn-wrk-mixed-c6525-25g-exp12-havail0-hori1-verti1-infi1-client-t8-c512-d30-R6000-N5
# ./nomad-hr-wrk-mixed-c6525-25g-exp14-havail0-hori0-verti1-infi1-client-t8-c512-d30-R500-N1
